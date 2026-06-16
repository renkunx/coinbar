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
        .frame(width: 268)
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
    }

    private var headerView: some View {
        HStack(spacing: 8) {
            Image(systemName: "bitcoinsign.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(.orange)
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
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(Self.coinSymbols[ticker.instId] ?? ticker.symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .fixedSize()

                Spacer(minLength: 6)

                HStack(spacing: 8) {
                    Text(Format.menuBarPrice(ticker.last))
                        .font(.system(size: 13, weight: .bold))
                        .monospacedDigit()
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .layoutPriority(1)

                    changeBadge(ticker)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            lowHighRow(ticker)
        }
        .padding(.vertical, 6)
        .padding(.trailing, 2)
    }

    private func lowHighRow(_ ticker: Ticker) -> some View {
        HStack(spacing: 12) {
            Text("最低 " + Format.menuBarPrice(ticker.low24h))
            Text("最高 " + Format.menuBarPrice(ticker.high24h))
        }
        .font(.system(size: 10, weight: .regular))
        .foregroundColor(.secondary)
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
