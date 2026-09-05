import SwiftUI
import AppKit
import Combine

/// 上次价格快照缓存（启动时立即显示，不等网络）
private struct TickerCache: Codable {
    let savedAt: Date
    let tickers: [String: Ticker]
}

@MainActor
final class PriceStore: ObservableObject {
    @Published var tickers: [String: Ticker] = [:]
    @Published var candles: [String: [Candle]] = [:]
    @Published var candlesLoading: Bool = false
    @Published var currentIndex: Int = 0
    @Published var pageIndex: Int = 0
    @Published var isConnected: Bool = false

    let settings = AppSettings()
    private let webSocket = OKXWebSocketService()
    private let marketService = OKXMarketService()
    private let alertEngine = AlertEngine()
    private let notifier = NotificationService.shared
    private var rotationTimer: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()

    private var pendingTickers: [String: Ticker] = [:]
    private var flushWorkItem: DispatchWorkItem?

    /// K 线缓存有效期（秒），面板打开后 60 秒内不重复拉取
    private var lastCandlesFetch: Date = .distantPast

    /// 价格快照缓存（UserDefaults），写入节流
    private let tickerCacheKey = "tickerCacheJSON"
    private var lastCacheSave: Date = .distantPast

    var enabledTickers: [Ticker] {
        settings.enabledCoins.compactMap { tickers[$0.instId] }
    }

    var totalPages: Int {
        let count = settings.enabledCoins.count
        return max(1, Int(ceil(Double(count) / 4.0)))
    }

    var currentPageTickers: [Ticker] {
        let all = enabledTickers
        let start = min(pageIndex * 4, all.count)
        let end = min(start + 4, all.count)
        guard start < end else { return [] }
        return Array(all[start..<end])
    }

    var currentTicker: Ticker? {
        let all = enabledTickers
        guard !all.isEmpty else { return nil }
        let idx = min(currentIndex, all.count - 1)
        return all[idx]
    }

    init() {
        NSApp.setActivationPolicy(.accessory)
        webSocket.delegate = self

        settings.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                MenuBarLabelRenderer.invalidateCache()
                self?.onSubscriptionsChanged()
            }
            .store(in: &cancellables)

        loadCachedTickers()
        connect()
        startRotation()
    }

    /// 启动时读取上次价格快照，菜单栏首帧即可显示（可能过期，稍后由 REST/WS 刷新）
    private func loadCachedTickers() {
        guard let json = UserDefaults.standard.string(forKey: tickerCacheKey),
              let data = json.data(using: .utf8),
              let cache = try? JSONDecoder().decode(TickerCache.self, from: data) else { return }
        tickers = cache.tickers
    }

    /// 节流持久化价格快照（≥5 秒一次）
    private func persistTickers() {
        guard Date().timeIntervalSince(lastCacheSave) >= 5, !tickers.isEmpty else { return }
        let cache = TickerCache(savedAt: Date(), tickers: tickers)
        if let data = try? JSONEncoder().encode(cache),
           let json = String(data: data, encoding: .utf8) {
            UserDefaults.standard.set(json, forKey: tickerCacheKey)
        }
        lastCacheSave = Date()
    }

    private func connect() {
        let instIds = settings.enabledCoins.map(\.instId)
        guard !instIds.isEmpty else { return }
        webSocket.connect(instIds: instIds)
        warmUpTickers(instIds: instIds)
    }

    /// REST 快照预热：并行拉取全部币种最新价，早于 WS 首推填充，走同一合并/持久化路径
    private func warmUpTickers(instIds: [String]) {
        Task { [weak self] in
            await withTaskGroup(of: Ticker?.self) { group in
                for instId in instIds {
                    group.addTask {
                        await self?.marketService.fetchTicker(instId: instId)
                    }
                }
                for await ticker in group {
                    guard let ticker else { continue }
                    self?.enqueueTicker(ticker)
                }
            }
        }
    }

    private func onSubscriptionsChanged() {
        pageIndex = 0
        currentIndex = 0
        tickers = [:]
        candles = [:]
        lastCandlesFetch = .distantPast
        connect()
    }

    // MARK: - 预警管理（UI 通过此处操作以同步清理引擎运行态）

    func addAlert(_ alert: PriceAlert) {
        settings.addAlert(alert)
    }

    func updateAlert(_ updated: PriceAlert) {
        settings.updateAlert(updated)
        // 编辑视为新规则，清掉旧状态以便重新首帧同步
        alertEngine.removeState(updated.id)
    }

    func removeAlert(id: UUID) {
        settings.removeAlert(id: id)
        alertEngine.removeState(id)
    }

    func removeCoinWithAlerts(instId: String) {
        alertEngine.clearInstId(instId, alerts: settings.alerts)
        settings.removeCoin(instId: instId)
    }

    func clearAlertHistory() {
        settings.clearHistory()
    }

    private func startRotation() {
        rotationTimer?.cancel()
        rotationTimer = Timer.publish(every: settings.rotateInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.rotate()
            }
    }

    func updateRotateInterval(_ interval: Double) {
        settings.rotateInterval = interval
        startRotation()
    }

    @MainActor
    func openSettings() {
        SettingsWindowManager.shared.open(priceStore: self)
    }

    private func enqueueTicker(_ ticker: Ticker) {
        pendingTickers[ticker.instId] = ticker
        flushWorkItem?.cancel()
        // 首帧快路径：暂无任何数据（如首次启动无缓存）时立即 flush，不等 250ms 合并
        guard !tickers.isEmpty else {
            flushPendingTickers()
            return
        }
        let workItem = DispatchWorkItem { [weak self] in
            self?.flushPendingTickers()
        }
        flushWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(250), execute: workItem)
    }

    private func flushPendingTickers() {
        guard !pendingTickers.isEmpty else { return }
        let updatedTickers = Array(pendingTickers.values)
        var newTickers = tickers
        for (instId, ticker) in pendingTickers {
            newTickers[instId] = ticker
        }
        pendingTickers = [:]
        tickers = newTickers
        persistTickers()
        evaluateAlerts(updatedTickers)
    }

    /// 对本轮刷新涉及的 ticker 跑预警判定，命中则记录历史并发系统通知
    private func evaluateAlerts(_ updatedTickers: [Ticker]) {
        guard settings.alertsEnabled else { return }
        let alerts = settings.alerts
        guard !alerts.isEmpty else { return }
        let period = settings.pricePeriod
        for ticker in updatedTickers {
            let triggers = alertEngine.evaluate(alerts: alerts, ticker: ticker, period: period)
            for record in triggers {
                settings.appendHistory(record)
                notifier.send(record)
            }
        }
    }

    /// 按需拉取全部已启用币种的 24h K 线（15m × 96），60 秒内命中缓存
    func refreshCandles() async {
        let instIds = settings.enabledCoins.map(\.instId)
        guard !instIds.isEmpty else { return }
        guard Date().timeIntervalSince(lastCandlesFetch) > 60 || candles.isEmpty else { return }
        guard !candlesLoading else { return }

        candlesLoading = true
        defer { candlesLoading = false }

        var result: [String: [Candle]] = [:]
        await withTaskGroup(of: (String, [Candle]).self) { group in
            for instId in instIds {
                group.addTask {
                    let candles = await self.marketService.fetchCandles(instId: instId)
                    return (instId, candles)
                }
            }
            for await (instId, candles) in group {
                result[instId] = candles
            }
        }

        candles = result
        // 全部失败时不更新缓存时间，下次打开面板可立即重试
        if result.values.contains(where: { !$0.isEmpty }) {
            lastCandlesFetch = Date()
        }
    }

    private func rotate() {
        guard settings.displayMode == .single || settings.displayMode == .stack else { return }

        if settings.displayMode == .single {
            let count = settings.enabledCoins.count
            guard count > 1 else { return }
            currentIndex = (currentIndex + 1) % count
        } else {
            guard totalPages > 1 else { return }
            pageIndex = (pageIndex + 1) % totalPages
        }
    }
}

extension PriceStore: OKXWebSocketServiceDelegate {
    nonisolated func webSocketService(_ service: OKXWebSocketService, didReceiveTicker ticker: Ticker) {
        DispatchQueue.main.async {
            self.enqueueTicker(ticker)
        }
    }

    nonisolated func webSocketServiceDidChangeStatus(_ service: OKXWebSocketService, connected: Bool) {
        DispatchQueue.main.async {
            self.isConnected = connected
            // 重连后清空预警状态，使下一次刷新退化为首帧同步（不发通知，避免误报）
            if connected {
                self.alertEngine.reset()
            }
        }
    }
}
