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

final class AppSettings: ObservableObject {
    static let allCoins: [Coin] = [
        Coin(instId: "BTC-USDT", symbol: "BTC"),
        Coin(instId: "ETH-USDT", symbol: "ETH"),
        Coin(instId: "SOL-USDT", symbol: "SOL"),
        Coin(instId: "BNB-USDT", symbol: "BNB"),
        Coin(instId: "XRP-USDT", symbol: "XRP"),
        Coin(instId: "DOGE-USDT", symbol: "DOGE")
    ]

    private static let defaultEnabled = ["BTC-USDT", "ETH-USDT", "SOL-USDT"]

    @AppStorage("enabledInstIdsJSON") private var enabledInstIdsJSON: String = ""

    @AppStorage("displayMode") var displayModeRaw: String = DisplayMode.single.rawValue
    @AppStorage("rotateInterval") var rotateInterval: Double = 3.0
    @AppStorage("showChangePct") var showChangePct: Bool = true
    @AppStorage("priceColorMode") var priceColorModeRaw: String = PriceColorMode.greenUpRedDown.rawValue

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
        Self.allCoins.filter { enabledInstIds.contains($0.instId) }
    }

    var priceColorMode: PriceColorMode {
        get { PriceColorMode(rawValue: priceColorModeRaw) ?? .greenUpRedDown }
        set { priceColorModeRaw = newValue.rawValue }
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
