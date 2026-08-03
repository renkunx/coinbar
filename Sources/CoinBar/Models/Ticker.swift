import Foundation

struct Ticker: Codable {
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

    /// 从 OKX ticker JSON（WS 与 REST 同构）解析，字段缺失时返回 nil
    static func parse(json: [String: Any]) -> Ticker? {
        guard let instId = json["instId"] as? String,
              let lastStr = json["last"] as? String,
              let last = Double(lastStr),
              let open24hStr = json["open24h"] as? String,
              let open24h = Double(open24hStr) else { return nil }

        let sodUtc0: Double = {
            guard let s = json["sodUtc0"] as? String, let v = Double(s) else { return open24h }
            return v
        }()
        let sodUtc8: Double = {
            guard let s = json["sodUtc8"] as? String, let v = Double(s) else { return open24h }
            return v
        }()
        let high24h: Double = {
            guard let s = json["high24h"] as? String, let v = Double(s) else { return 0 }
            return v
        }()
        let low24h: Double = {
            guard let s = json["low24h"] as? String, let v = Double(s) else { return 0 }
            return v
        }()
        let vol24h: Double = {
            guard let s = json["vol24h"] as? String, let v = Double(s) else { return 0 }
            return v
        }()

        return Ticker(
            instId: instId,
            last: last,
            open24h: open24h,
            sodUtc0: sodUtc0,
            sodUtc8: sodUtc8,
            high24h: high24h,
            low24h: low24h,
            vol24h: vol24h
        )
    }
}
