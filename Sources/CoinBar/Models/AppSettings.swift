import SwiftUI

enum DisplayMode: String, CaseIterable {
    case single
    case stack
}

final class AppSettings: ObservableObject {
    static let allCoins: [Coin] = [
        Coin(instId: "BTC-USDT", symbol: "₿"),
        Coin(instId: "ETH-USDT", symbol: "Ξ"),
        Coin(instId: "SOL-USDT", symbol: "◎"),
        Coin(instId: "BNB-USDT", symbol: "BNB"),
        Coin(instId: "XRP-USDT", symbol: "XRP"),
        Coin(instId: "DOGE-USDT", symbol: "Ð"),
        Coin(instId: "ADA-USDT", symbol: "ADA"),
        Coin(instId: "AVAX-USDT", symbol: "AVAX"),
        Coin(instId: "DOT-USDT", symbol: "DOT"),
        Coin(instId: "LINK-USDT", symbol: "LINK"),
        Coin(instId: "UNI-USDT", symbol: "UNI"),
        Coin(instId: "ATOM-USDT", symbol: "ATOM"),
        Coin(instId: "MATIC-USDT", symbol: "MATIC"),
        Coin(instId: "APT-USDT", symbol: "APT"),
        Coin(instId: "ARB-USDT", symbol: "ARB"),
        Coin(instId: "OP-USDT", symbol: "OP"),
        Coin(instId: "NEAR-USDT", symbol: "NEAR"),
        Coin(instId: "ETC-USDT", symbol: "ETC"),
        Coin(instId: "FIL-USDT", symbol: "FIL"),
        Coin(instId: "LTC-USDT", symbol: "LTC"),
    ]

    private static let defaultEnabled = ["BTC-USDT", "ETH-USDT", "SOL-USDT"]

    @AppStorage("enabledInstIdsJSON") private var enabledInstIdsJSON: String = ""

    @AppStorage("displayMode") var displayModeRaw: String = DisplayMode.single.rawValue
    @AppStorage("rotateInterval") var rotateInterval: Double = 3.0
    @AppStorage("showChangePct") var showChangePct: Bool = true

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
}
