import Foundation

/// OKX K 线数据（15m 粒度，覆盖 24 小时 = 96 根）
struct Candle {
    let ts: TimeInterval
    let open: Double
    let high: Double
    let low: Double
    let close: Double
}
