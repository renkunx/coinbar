import SwiftUI
import AppKit

enum DisplayMode: String, CaseIterable {
    case single
    case stack
}

enum PriceColorMode: String, CaseIterable {
    case greenUpRedDown
    case redUpGreenDown
}

enum PricePeriod: String, CaseIterable {
    case utc8
    case utc0
    case rolling24h
}

final class AppSettings: ObservableObject {
    // 内置默认币种（恢复默认 / 首次启动兜底）
    static let defaultCoins: [Coin] = [
        Coin(instId: "BTC-USDT", symbol: "BTC"),
        Coin(instId: "ETH-USDT", symbol: "ETH"),
        Coin(instId: "SOL-USDT", symbol: "SOL"),
        Coin(instId: "GRAM-USDT", symbol: "GRAM"),
        Coin(instId: "BNB-USDT", symbol: "BNB"),
        Coin(instId: "XRP-USDT", symbol: "XRP"),
        Coin(instId: "DOGE-USDT", symbol: "DOGE"),
        Coin(instId: "ADA-USDT", symbol: "ADA"),
        Coin(instId: "AVAX-USDT", symbol: "AVAX"),
    ]

    private static let defaultEnabled = ["BTC-USDT", "ETH-USDT", "SOL-USDT", "GRAM-USDT"]

    @AppStorage("enabledInstIdsJSON") private var enabledInstIdsJSON: String = ""

    // 完整币种列表（内置 + 自定义），持久化
    @AppStorage("allCoinsJSON") private var allCoinsJSON: String = ""

    var allCoins: [Coin] {
        get {
            guard !allCoinsJSON.isEmpty,
                  let data = allCoinsJSON.data(using: .utf8),
                  let coins = try? JSONDecoder().decode([Coin].self, from: data),
                  !coins.isEmpty else {
                return Self.defaultCoins
            }
            return coins
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let json = String(data: data, encoding: .utf8) {
                allCoinsJSON = json
            }
            objectWillChange.send()
        }
    }

    /// 引导式添加自定义币种：基础币符号 + 计价币（USDT/USDC）
    @discardableResult
    func addCoin(baseSymbol: String, quoteCoin: String) -> Bool {
        let base = baseSymbol.trimmingCharacters(in: .whitespaces).uppercased()
        guard !base.isEmpty, base.allSatisfy({ $0.isLetter || $0.isNumber }) else { return false }
        let instId = "\(base)-\(quoteCoin)"
        guard !allCoins.contains(where: { $0.instId == instId }) else { return false }
        allCoins.append(Coin(instId: instId, symbol: base))
        return true
    }

    /// 删除币种（内置/自定义均可删）；连带删除其下预警规则（历史保留）
    func removeCoin(instId: String) {
        allCoins.removeAll { $0.instId == instId }
        enabledInstIds.removeAll { $0 == instId }
        alerts.removeAll { $0.instId == instId }
    }

    /// 恢复内置默认币种列表
    func resetCoinsToDefault() {
        allCoins = Self.defaultCoins
    }

    @AppStorage("displayMode") var displayModeRaw: String = DisplayMode.single.rawValue
    @AppStorage("rotateInterval") var rotateInterval: Double = 3.0
    @AppStorage("showChangePct") var showChangePct: Bool = true
    @AppStorage("priceColorMode") var priceColorModeRaw: String = PriceColorMode.greenUpRedDown.rawValue
    @AppStorage("pricePeriod") var pricePeriodRaw: String = PricePeriod.utc8.rawValue

    var enabledInstIds: [String] {
        get {
            if enabledInstIdsJSON.isEmpty { return Self.defaultEnabled }
            guard let data = enabledInstIdsJSON.data(using: .utf8),
                  let ids = try? JSONDecoder().decode([String].self, from: data) else {
                return Self.defaultEnabled
            }
            return ids
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let json = String(data: data, encoding: .utf8) {
                enabledInstIdsJSON = json
            }
        }
    }

    var displayMode: DisplayMode {
        get { DisplayMode(rawValue: displayModeRaw) ?? .single }
        set { displayModeRaw = newValue.rawValue }
    }

    var enabledCoins: [Coin] {
        allCoins.filter { enabledInstIds.contains($0.instId) }
    }

    var priceColorMode: PriceColorMode {
        get { PriceColorMode(rawValue: priceColorModeRaw) ?? .greenUpRedDown }
        set { priceColorModeRaw = newValue.rawValue }
    }

    var pricePeriod: PricePeriod {
        get { PricePeriod(rawValue: pricePeriodRaw) ?? .utc8 }
        set { pricePeriodRaw = newValue.rawValue }
    }

    // MARK: - 预警

    /// 全局总开关：一键暂停所有预警（仍记录历史，但不发通知也不触发判定）
    @AppStorage("alertsEnabled") var alertsEnabled: Bool = true

    /// 预警规则（持久化）
    @AppStorage("alertsJSON") private var alertsJSON: String = ""

    /// 触发历史（持久化，上限 200 条，最老先出）
    @AppStorage("alertHistoryJSON") private var alertHistoryJSON: String = ""

    /// 历史写入节流：≥5 秒合并一次，避免高频行情刷盘
    private var pendingHistory: [AlertTriggerRecord] = []
    private var lastHistorySave: Date = .distantPast
    private var historyFlushScheduled = false

    static let historyLimit = 200

    var alerts: [PriceAlert] {
        get {
            guard !alertsJSON.isEmpty,
                  let data = alertsJSON.data(using: .utf8),
                  let alerts = try? JSONDecoder().decode([PriceAlert].self, from: data) else {
                return []
            }
            return alerts
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let json = String(data: data, encoding: .utf8) {
                alertsJSON = json
            }
            objectWillChange.send()
        }
    }

    /// 添加一条预警规则（重复规则交由调用方/UI 控制；此处只追加）
    @discardableResult
    func addAlert(_ alert: PriceAlert) -> Bool {
        var current = alerts
        guard !current.contains(where: { $0.id == alert.id }) else { return false }
        current.append(alert)
        alerts = current
        return true
    }

    /// 按 id 删除规则
    func removeAlert(id: UUID) {
        var current = alerts
        current.removeAll { $0.id == id }
        alerts = current
    }

    /// 更新一条规则（按 id 替换）
    func updateAlert(_ updated: PriceAlert) {
        var current = alerts
        guard let idx = current.firstIndex(where: { $0.id == updated.id }) else { return }
        current[idx] = updated
        alerts = current
    }

    var alertHistory: [AlertTriggerRecord] {
        get {
            guard !alertHistoryJSON.isEmpty,
                  let data = alertHistoryJSON.data(using: .utf8),
                  let records = try? JSONDecoder().decode([AlertTriggerRecord].self, from: data) else {
                return []
            }
            return records
        }
    }

    /// 追加一条触发记录并裁剪到上限；写入节流合并以减少刷盘频率。
    func appendHistory(_ record: AlertTriggerRecord) {
        pendingHistory.append(record)

        let now = Date()
        if now.timeIntervalSince(lastHistorySave) >= 5 {
            flushPendingHistory()
        } else if !historyFlushScheduled {
            scheduleHistoryFlush()
        }
    }

    /// 立即清空所有历史
    func clearHistory() {
        pendingHistory.removeAll()
        alertHistoryJSON = ""
        lastHistorySave = Date()
        objectWillChange.send()
    }

    private func scheduleHistoryFlush() {
        historyFlushScheduled = true
        let delay = max(0, 5 - Date().timeIntervalSince(lastHistorySave))
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.flushPendingHistory()
        }
    }

    private func flushPendingHistory() {
        guard !pendingHistory.isEmpty else {
            historyFlushScheduled = false
            return
        }
        var merged = alertHistory + pendingHistory
        pendingHistory.removeAll()
        if merged.count > Self.historyLimit {
            merged = Array(merged.suffix(Self.historyLimit))
        }
        if let data = try? JSONEncoder().encode(merged),
           let json = String(data: data, encoding: .utf8) {
            alertHistoryJSON = json
        }
        lastHistorySave = Date()
        historyFlushScheduled = false
        objectWillChange.send()
    }

    func changeColor(isUp: Bool, isZero: Bool) -> NSColor {
        if isZero { return .secondaryLabelColor }
        switch priceColorMode {
        case .greenUpRedDown:
            return isUp ? .systemGreen : .systemRed
        case .redUpGreenDown:
            return isUp ? .systemRed : .systemGreen
        }
    }
}
