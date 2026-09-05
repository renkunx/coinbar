import Foundation

/// 预警类型：绝对价格突破 / 涨跌幅
enum AlertType: String, Codable, CaseIterable {
    case price
    case changePct
}

/// 方向：up = 突破上方阈值；down = 突破下方阈值
enum AlertDirection: String, Codable, CaseIterable {
    case up
    case down
}

/// 一条预警规则
struct PriceAlert: Identifiable, Codable, Equatable {
    let id: UUID
    let instId: String
    let type: AlertType
    let direction: AlertDirection
    /// price：价格值（>0）；changePct：正数百分比值（0...100），方向由 direction 决定符号
    let threshold: Double
    var enabled: Bool
    var note: String?

    init(
        id: UUID = UUID(),
        instId: String,
        type: AlertType,
        direction: AlertDirection,
        threshold: Double,
        enabled: Bool = true,
        note: String? = nil
    ) {
        self.id = id
        self.instId = instId
        self.type = type
        self.direction = direction
        self.threshold = threshold
        self.enabled = enabled
        self.note = note
    }

    /// 判定当前 ticker 是否已处于「越过阈值」侧
    func isBreached(by ticker: Ticker, period: PricePeriod) -> Bool {
        switch (type, direction) {
        case (.price, .up):    return ticker.last >= threshold
        case (.price, .down):  return ticker.last <= threshold
        case (.changePct, .up):
            return ticker.changePct(for: period) >= threshold
        case (.changePct, .down):
            return ticker.changePct(for: period) <= -threshold
        }
    }

    /// 人类可读的条件描述（不含动态价格），用于列表与通知
    func conditionDescription(symbol: String) -> String {
        switch type {
        case .price:
            let op = direction == .up ? "≥" : "≤"
            return "\(symbol) \(op) \(Format.price(threshold))"
        case .changePct:
            let op = direction == .up ? "涨幅 ≥" : "跌幅 ≥"
            return "\(symbol) \(op) \(Format.trimmedDecimal(threshold))%"
        }
    }
}

/// 一次触发的历史记录
struct AlertTriggerRecord: Identifiable, Codable, Equatable {
    let id: UUID
    let instId: String
    let symbol: String
    let date: Date
    let type: AlertType
    let direction: AlertDirection
    let threshold: Double
    let triggeredPrice: Double
    let triggeredChangePct: Double
    let note: String?

    init(
        id: UUID = UUID(),
        instId: String,
        symbol: String,
        date: Date = Date(),
        type: AlertType,
        direction: AlertDirection,
        threshold: Double,
        triggeredPrice: Double,
        triggeredChangePct: Double,
        note: String? = nil
    ) {
        self.id = id
        self.instId = instId
        self.symbol = symbol
        self.date = date
        self.type = type
        self.direction = direction
        self.threshold = threshold
        self.triggeredPrice = triggeredPrice
        self.triggeredChangePct = triggeredChangePct
        self.note = note
    }

    /// 通知/历史列表用的一行文案
    var title: String {
        switch type {
        case .price:
            let verb = direction == .up ? "突破" : "跌破"
            return "\(symbol) \(verb) \(Format.price(threshold))"
        case .changePct:
            let verb = direction == .up ? "涨幅达" : "跌幅达"
            return "\(symbol) \(verb) \(Format.changePct(triggeredChangePct))"
        }
    }
}
