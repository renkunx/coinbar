import SwiftUI
import AppKit
import Combine

@MainActor
final class PriceStore: ObservableObject {
    @Published var tickers: [String: Ticker] = [:]
    @Published var currentIndex: Int = 0
    @Published var pageIndex: Int = 0
    @Published var isConnected: Bool = false

    let settings = AppSettings()
    private let webSocket = OKXWebSocketService()
    private var rotationTimer: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()

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
                self?.onSubscriptionsChanged()
            }
            .store(in: &cancellables)

        connect()
        startRotation()
    }

    private func connect() {
        let instIds = settings.enabledCoins.map(\.instId)
        guard !instIds.isEmpty else { return }
        webSocket.connect(instIds: instIds)
    }

    private func onSubscriptionsChanged() {
        pageIndex = 0
        currentIndex = 0
        tickers = [:]
        connect()
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
            self.tickers[ticker.instId] = ticker
        }
    }

    nonisolated func webSocketServiceDidChangeStatus(_ service: OKXWebSocketService, connected: Bool) {
        DispatchQueue.main.async {
            self.isConnected = connected
        }
    }
}
