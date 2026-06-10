import SwiftUI

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
        VStack(alignment: .leading, spacing: 6) {
            headerView

            Divider()

            tickerList

            Divider()

            footerView
        }
        .frame(width: 260)
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
    }

    private var headerView: some View {
        HStack {
            Text("币吧")
                .font(.headline)
            Spacer()
            Circle()
                .fill(priceStore.isConnected ? Color.green : Color.red)
                .frame(width: 6, height: 6)
        }
    }

    private var tickerList: some View {
        let tickers = priceStore.enabledTickers
        if tickers.isEmpty {
            return AnyView(
                HStack {
                    Spacer()
                    Text("等待数据...")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.vertical, 8)
            )
        }
        return AnyView(
            VStack(spacing: 4) {
                ForEach(tickers, id: \.instId) { ticker in
                    coinRow(ticker)
                }
            }
        )
    }

    private func coinRow(_ ticker: Ticker) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Text(Self.coinSymbols[ticker.instId] ?? ticker.symbol)
                    .font(.system(size: 11, weight: .semibold))
                Text(Format.price(ticker.last))
                    .font(.system(size: 11, weight: .bold))
                    .monospacedDigit()
                Text(Format.changePct(ticker.changePct))
                    .font(.system(size: 10))
                    .foregroundColor(ticker.isZero ? .secondary : (ticker.isUp ? .green : .red))
            }

            HStack(spacing: 8) {
                HStack(spacing: 2) {
                    Text("H:")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Text(Format.price(ticker.high24h))
                        .font(.system(size: 9))
                        .monospacedDigit()
                }
                HStack(spacing: 2) {
                    Text("L:")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Text(Format.price(ticker.low24h))
                        .font(.system(size: 9))
                        .monospacedDigit()
                }
                HStack(spacing: 2) {
                    Text("Vol:")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Text(Format.volume(ticker.vol24h))
                        .font(.system(size: 9))
                        .monospacedDigit()
                }
            }
            .lineLimit(1)
        }
        .padding(.vertical, 1)
    }

    private var footerView: some View {
        HStack {
            Button("设置...") {
                priceStore.openSettings()
            }
            .buttonStyle(.link)
            .font(.system(size: 10))

            Spacer()

            Button("退出") {
                NSApp.terminate(nil)
            }
            .buttonStyle(.link)
            .font(.system(size: 10))
        }
    }
}
