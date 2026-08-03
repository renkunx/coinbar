import Foundation

/// OKX 公开行情 REST 客户端（按需拉取 K 线，供趋势图使用）
final class OKXMarketService {
    private let baseURL = URL(string: "https://www.okx.com/api/v5/market/candles")!
    private let tickerURL = URL(string: "https://www.okx.com/api/v5/market/ticker")!
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        session = URLSession(configuration: config)
    }

    /// 拉取 K 线（OKX 返回最新在前，这里转为时间升序）
    func fetchCandles(instId: String, bar: String = "15m", limit: Int = 96) async -> [Candle] {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "instId", value: instId),
            URLQueryItem(name: "bar", value: bar),
            URLQueryItem(name: "limit", value: String(limit)),
        ]

        guard let url = components.url,
              let (data, response) = try? await session.data(from: url),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              (json["code"] as? String) == "0",
              let rows = json["data"] as? [[String]] else { return [] }

        // OKX K 线行格式: [ts, o, h, l, c, vol, ...]，最新在前
        var candles: [Candle] = []
        candles.reserveCapacity(rows.count)
        for row in rows.reversed() {
            guard row.count >= 5,
                  let ts = TimeInterval(row[0]),
                  let open = Double(row[1]),
                  let high = Double(row[2]),
                  let low = Double(row[3]),
                  let close = Double(row[4]) else { continue }
            candles.append(Candle(ts: ts, open: open, high: high, low: low, close: close))
        }
        return candles
    }

    /// 拉取单个币种的最新 ticker 快照（REST，比 WS 首推更快，用于启动预热）
    func fetchTicker(instId: String) async -> Ticker? {
        var components = URLComponents(url: tickerURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "instId", value: instId)]

        guard let url = components.url,
              let (data, response) = try? await session.data(from: url),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              (json["code"] as? String) == "0",
              let rows = json["data"] as? [[String: Any]],
              let row = rows.first else { return nil }

        return Ticker.parse(json: row)
    }
}
