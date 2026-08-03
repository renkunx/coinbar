import SwiftUI
import AppKit

struct MenuBarPanel: View {
    @ObservedObject var priceStore: PriceStore

    @State private var coinSymbols: [String: String] = [:]
    @State private var expandedInstId: String?

    private enum Column {
        static let symbol: CGFloat = 35
        static let price: CGFloat = 70
        static let change: CGFloat = 56
        static let trend: CGFloat = 58
        static let spacing: CGFloat = 6
    }

    private func buildCoinSymbols() -> [String: String] {
        var dict: [String: String] = [:]
        for coin in priceStore.settings.allCoins {
            dict[coin.instId] = coin.symbol
        }
        return dict
    }

    var body: some View {
        VStack(spacing: 10) {
            headerView
            Divider()
                .background(Color.white.opacity(0.12))
                .padding(.horizontal, 8)
            tickerList
            Divider()
                .background(Color.white.opacity(0.12))
                .padding(.horizontal, 8)
            footerView
        }
        .frame(width: 300)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.25), radius: 24, x: 0, y: 10)
        .onReceive(priceStore.settings.objectWillChange) { _ in
            DispatchQueue.main.async {
                coinSymbols = buildCoinSymbols()
            }
        }
        .onAppear {
            coinSymbols = buildCoinSymbols()
        }
        .task {
            await priceStore.refreshCandles()
        }
    }

    private var headerView: some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 3.5)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.69, blue: 0.13),
                                Color(red: 0.91, green: 0.48, blue: 0.04)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 20, height: 20)
                Image(systemName: "bitcoinsign")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(width: 20, height: 20)

            Text("币吧")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)

            Spacer()

            Text(periodLabel)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.1))
                )

            Circle()
                .fill(priceStore.isConnected ? Color.green : Color.red)
                .frame(width: 6, height: 6)
        }
        .padding(.bottom, 6)
    }

    private var periodLabel: String {
        switch priceStore.settings.pricePeriod {
        case .utc8: return "UTC+8"
        case .utc0: return "UTC+0"
        case .rolling24h: return "24H"
        }
    }

    private var tickerList: some View {
        let tickers = priceStore.enabledTickers

        if tickers.isEmpty {
            return AnyView(
                HStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.6)
                        .padding(.vertical, 16)
                    Spacer()
                }
            )
        }

        return AnyView(
            VStack(spacing: 2) {
                columnHeader
                ForEach(Array(tickers.enumerated()), id: \.element.instId) { index, ticker in
                    VStack(spacing: 0) {
                        coinRow(ticker)
                        if expandedInstId == ticker.instId {
                            expandedDetail(ticker)
                        }
                    }
                    if index < tickers.count - 1 {
                        Divider()
                            .opacity(0.3)
                    }
                }
            }
            .padding(.vertical, 4)
        )
    }

    // 表头列名：趋势作为列名，每行只填数值
    private var columnHeader: some View {
        HStack(spacing: Column.spacing) {
            Text("币种")
                .frame(width: Column.symbol, alignment: .leading)
            Text("最新")
                .frame(width: Column.price, alignment: .trailing)
            Text("涨跌")
                .frame(width: Column.change, alignment: .center)
            Spacer(minLength: 0)
            Text("24h 趋势")
                .frame(width: Column.trend, alignment: .trailing)
        }
        .font(.system(size: 9, weight: .medium))
        .foregroundColor(.secondary.opacity(0.7))
        .padding(.bottom, 4)
        .padding(.horizontal, 2)
    }

    private func coinRow(_ ticker: Ticker) -> some View {
        HStack(spacing: Column.spacing) {
            // 币种
            Text(coinSymbols[ticker.instId] ?? ticker.symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .frame(width: Column.symbol, alignment: .leading)

            // 最新价
            Text(Format.menuBarPrice(ticker.last))
                .font(.system(size: 13, weight: .bold))
                .monospacedDigit()
                .foregroundColor(.primary)
                .lineLimit(1)
                .frame(width: Column.price, alignment: .trailing)

            // 涨跌
            changeBadge(ticker)
                .frame(width: Column.change, alignment: .center)

            Spacer(minLength: 0)

            // 24h 趋势迷你图（点击整行展开详情）
            trendCell(ticker)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            expandedInstId = (expandedInstId == ticker.instId) ? nil : ticker.instId
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 2)
    }

    private func trendCell(_ ticker: Ticker) -> some View {
        Group {
            if let candles = priceStore.candles[ticker.instId], !candles.isEmpty {
                if let color = trendColor(for: candles) {
                    SparklineView(candles: candles, color: color)
                } else {
                    trendPlaceholder
                }
            } else if priceStore.candlesLoading {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: Column.trend, height: 22)
            } else {
                trendPlaceholder
            }
        }
        .frame(width: Column.trend, alignment: .trailing)
    }

    private var trendPlaceholder: some View {
        Text("--")
            .font(.system(size: 10, weight: .regular))
            .foregroundColor(.secondary.opacity(0.4))
            .frame(width: Column.trend, height: 22)
    }

    /// 趋势图颜色：按首尾 close 涨跌 + 用户的涨跌配色偏好
    private func trendColor(for candles: [Candle]) -> Color? {
        guard let first = candles.first, let last = candles.last, first.close > 0 else { return nil }
        let nsColor = priceStore.settings.changeColor(
            isUp: last.close >= first.close,
            isZero: last.close == first.close
        )
        return Color(nsColor: nsColor)
    }

    /// 展开详情：大趋势图 + 24h 低/高/成交量
    private func expandedDetail(_ ticker: Ticker) -> some View {
        VStack(spacing: 8) {
            if let candles = priceStore.candles[ticker.instId], !candles.isEmpty {
                if let color = trendColor(for: candles) {
                    TrendChartView(candles: candles, color: color)
                        .frame(maxWidth: .infinity)
                }
            } else {
                HStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.6)
                    Spacer()
                }
                .frame(height: 70)
            }

            HStack(spacing: Column.spacing) {
                Text("24h 低 \(Format.menuBarPrice(ticker.low24h))")
                Text("24h 高 \(Format.menuBarPrice(ticker.high24h))")
                Text("24h 量 \(Format.volume(ticker.vol24h))")
                Spacer(minLength: 0)
            }
            .font(.system(size: 9, weight: .medium))
            .monospacedDigit()
            .foregroundColor(.secondary.opacity(0.85))
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
    }

    private func changeBadge(_ ticker: Ticker) -> some View {
        let settings = priceStore.settings
        let period = settings.pricePeriod
        let nsColor = settings.changeColor(isUp: ticker.isUp(for: period), isZero: ticker.isZero(for: period))
        let bgColor = Color(nsColor: nsColor).opacity(ticker.isZero(for: period) ? 0.14 : 0.22)

        return Text(Format.changePct(ticker.changePct(for: period)))
            .font(.system(size: 9, weight: .semibold))
            .monospacedDigit()
            .foregroundColor(Color(nsColor: nsColor))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(bgColor)
            )
    }

    private var footerView: some View {
        HStack(spacing: 0) {
            Button(action: { priceStore.openSettings() }) {
                HStack(spacing: 4) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 10, weight: .medium))
                    Text("设置")
                        .font(.system(size: 11, weight: .medium))
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)

            Spacer()

            Button(action: { NSApp.terminate(nil) }) {
                HStack(spacing: 4) {
                    Text("退出")
                        .font(.system(size: 11, weight: .medium))
                    Image(systemName: "power")
                        .font(.system(size: 9, weight: .medium))
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
        }
        .padding(.top, 6)
    }
}
