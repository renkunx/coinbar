import Foundation

struct Ticker {
    let instId: String
    let last: Double
    let open24h: Double
    let sodUtc0: Double
    let sodUtc8: Double
    let high24h: Double
    let low24h: Double
    let vol24h: Double

    var symbol: String {
        instId.split(separator: "-").first.map(String.init) ?? instId
    }

    func open(for period: PricePeriod) -> Double {
        let value: Double
        switch period {
        case .utc8:     value = sodUtc8
        case .utc0:     value = sodUtc0
        case .rolling24h: value = open24h
        }
        return value > 0 ? value : open24h
    }

    func changePct(for period: PricePeriod) -> Double {
        let base = open(for: period)
        guard base > 0 else { return 0 }
        return ((last - base) / base) * 100
    }

    func isUp(for period: PricePeriod) -> Bool {
        changePct(for: period) >= 0
    }

    func isZero(for period: PricePeriod) -> Bool {
        changePct(for: period) == 0
    }
}
