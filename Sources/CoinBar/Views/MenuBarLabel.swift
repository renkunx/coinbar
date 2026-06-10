import SwiftUI

struct MenuBarLabel: View {
    @ObservedObject var priceStore: PriceStore

    private static let coinSymbols: [String: String] = {
        var dict: [String: String] = [:]
        for coin in AppSettings.allCoins {
            dict[coin.instId] = coin.symbol
        }
        return dict
    }()

    var body: some View {
        let tickers = priceStore.currentPageTickers

        if case .single = priceStore.settings.displayMode {
            singleCell(ticker: priceStore.currentTicker)
                .frame(height: 22)
        } else {
            switch tickers.count {
            case 0:
                Text("--")
                    .font(.system(size: 10))
            case 1:
                singleCell(ticker: tickers[0])
            case 2:
                twoColumns(tickers: tickers)
            case 3:
                threeLayout(tickers: tickers)
            default:
                gridLayout(tickers: Array(tickers.prefix(4)))
            }
        }
    }

    @ViewBuilder
    private func singleCell(ticker: Ticker?) -> some View {
        if let ticker {
            HStack(spacing: 3) {
                Text(Self.coinSymbols[ticker.instId] ?? ticker.symbol)
                    .font(.system(size: 10, weight: .medium))
                Text(Format.compactPrice(ticker.last))
                    .font(.system(size: 10, weight: .bold))
                    .monospacedDigit()
                if priceStore.settings.showChangePct {
                    changeText(ticker)
                }
            }
        } else {
            Text("Loading...")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private func twoColumns(tickers: [Ticker]) -> some View {
        HStack(spacing: 6) {
            ForEach(Array(tickers.prefix(2)), id: \.instId) { ticker in
                coinCell(ticker)
            }
        }
    }

    @ViewBuilder
    private func threeLayout(tickers: [Ticker]) -> some View {
        let t0 = tickers[0]
        let t1 = tickers[1]
        let t2 = tickers[2]

        HStack(spacing: 4) {
            coinCell(t0)
                .frame(maxHeight: .infinity, alignment: .center)

            VStack(spacing: 2) {
                coinCell(t1)
                coinCell(t2)
            }
        }
        .frame(height: 34)
    }

    @ViewBuilder
    private func gridLayout(tickers: [Ticker]) -> some View {
        VStack(spacing: 1) {
            HStack(spacing: 6) {
                if tickers.indices.contains(0) { coinCell(tickers[0]) }
                if tickers.indices.contains(1) { coinCell(tickers[1]) }
            }
            HStack(spacing: 6) {
                if tickers.indices.contains(2) { coinCell(tickers[2]) }
                if tickers.indices.contains(3) { coinCell(tickers[3]) }
            }
        }
    }

    @ViewBuilder
    private func coinCell(_ ticker: Ticker) -> some View {
        HStack(spacing: 2) {
            Text(Self.coinSymbols[ticker.instId] ?? ticker.symbol)
                .font(.system(size: 8, weight: .medium))
            Text(Format.compactPrice(ticker.last))
                .font(.system(size: 8, weight: .bold))
                .monospacedDigit()
            if priceStore.settings.showChangePct {
                changeText(ticker)
            }
        }
    }

    @ViewBuilder
    private func changeText(_ ticker: Ticker) -> some View {
        Text(Format.changePct(ticker.changePct))
            .font(.system(size: 7, weight: .medium))
            .foregroundColor(ticker.isZero ? .secondary : (ticker.isUp ? .green : .red))
    }
}
