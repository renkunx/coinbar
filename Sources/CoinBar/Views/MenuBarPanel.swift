import SwiftUI
import AppKit

struct MenuBarPanel: View {
    @ObservedObject var priceStore: PriceStore

    private static let coinSymbols: [String: String] = {
        var dict: [String: String] = [:]
        for coin in AppSettings.allCoins {
            dict[coin.instId] = coin.symbol
        }
        return dict
    }()

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
                .padding(.horizontal, -10)
            tickerList
            Divider()
                .padding(.horizontal, -10)
            footerView
        }
        .frame(width: 250)
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
    }

    private var headerView: some View {
        HStack(spacing: 6) {
            Image(systemName: "bitcoinsign.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(.orange)
            Text("币吧")
                .font(.system(size: 12, weight: .semibold))
            Spacer()

            Text(periodLabel)
                .font(.system(size: 8))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.secondary.opacity(0.12))
                )

            Circle()
                .fill(priceStore.isConnected ? Color.green : Color.red)
                .frame(width: 5, height: 5)
        }
        .padding(.bottom, 4)
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
            VStack(spacing: 0) {
                ForEach(Array(tickers.enumerated()), id: \.element.instId) { index, ticker in
                    coinRow(ticker)
                    if index < tickers.count - 1 {
                        Divider()
                            .opacity(0.3)
                    }
                }
            }
            .padding(.vertical, 4)
        )
    }

    private func coinRow(_ ticker: Ticker) -> some View {
        return HStack(spacing: 0) {
            Text(Self.coinSymbols[ticker.instId] ?? ticker.symbol)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 16, alignment: .leading)

            Spacer().frame(width: 6)

            Text(Format.menuBarPrice(ticker.last))
                .font(.system(size: 12, weight: .bold))
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .trailing)

            Spacer().frame(width: 8)

            changeBadge(ticker)
        }
        .padding(.vertical, 4)
        .padding(.trailing, 2)
    }

    private func changeBadge(_ ticker: Ticker) -> some View {
        let settings = priceStore.settings
        let period = settings.pricePeriod
        let nsColor = settings.changeColor(isUp: ticker.isUp(for: period), isZero: ticker.isZero(for: period))
        let bgColor = Color(nsColor: nsColor).opacity(ticker.isZero(for: period) ? 0.12 : 0.18)

        return Text(Format.changePct(ticker.changePct(for: period)))
            .font(.system(size: 9, weight: .bold))
            .monospacedDigit()
            .foregroundColor(Color(nsColor: nsColor))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(bgColor)
            )
    }

    private var footerView: some View {
        HStack {
            Button(action: { priceStore.openSettings() }) {
                HStack(spacing: 3) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 9))
                    Text("设置")
                        .font(.system(size: 10))
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)

            Spacer()

            Button(action: { NSApp.terminate(nil) }) {
                HStack(spacing: 3) {
                    Text("退出")
                        .font(.system(size: 10))
                    Image(systemName: "power")
                        .font(.system(size: 8))
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
        }
        .padding(.top, 4)
    }
}
