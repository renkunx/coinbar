import Foundation

struct Ticker {
    let instId: String
    let last: Double
    let open24h: Double
    let high24h: Double
    let low24h: Double
    let vol24h: Double

    var changePct: Double {
        guard open24h > 0 else { return 0 }
        return ((last - open24h) / open24h) * 100
    }

    var isUp: Bool { changePct >= 0 }

    var isZero: Bool { changePct == 0 }

    var symbol: String {
        instId.split(separator: "-").first.map(String.init) ?? instId
    }
}
