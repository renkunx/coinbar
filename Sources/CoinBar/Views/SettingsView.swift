import SwiftUI

struct SettingsView: View {
    @ObservedObject var priceStore: PriceStore

    var body: some View {
        TabView {
            CoinSettingsTab(settings: priceStore.settings)
                .tabItem { Label("币种", systemImage: "bitcoinsign.circle") }

            DisplaySettingsTab(
                settings: priceStore.settings,
                onRotateIntervalChanged: { priceStore.updateRotateInterval($0) }
            )
            .tabItem { Label("显示", systemImage: "gearshape") }

            AboutTab()
                .tabItem { Label("关于", systemImage: "info.circle") }
        }
        .frame(width: 360, height: 420)
    }
}

private struct CoinSettingsTab: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("选择监控币种")
                .font(.headline)
                .padding(.horizontal)

            HStack {
                Button("全选") { settings.enabledInstIds = AppSettings.allCoins.map(\.instId) }
                    .font(.system(size: 10))
                Button("默认") { settings.enabledInstIds = ["BTC-USDT", "ETH-USDT", "SOL-USDT"] }
                    .font(.system(size: 10))
                Button("清空") { settings.enabledInstIds = [] }
                    .font(.system(size: 10))
            }
            .padding(.horizontal)

            List(AppSettings.allCoins) { coin in
                Toggle(isOn: binding(for: coin.instId)) {
                    HStack(spacing: 6) {
                        Text(coin.symbol)
                            .font(.system(size: 12, weight: .medium))
                        Text(coin.instId)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical)
    }

    private func binding(for instId: String) -> Binding<Bool> {
        Binding(
            get: { settings.enabledInstIds.contains(instId) },
            set: { enabled in
                if enabled {
                    if !settings.enabledInstIds.contains(instId) {
                        settings.enabledInstIds.append(instId)
                    }
                } else {
                    settings.enabledInstIds.removeAll { $0 == instId }
                }
            }
        )
    }
}

private struct DisplaySettingsTab: View {
    @ObservedObject var settings: AppSettings
    let onRotateIntervalChanged: (Double) -> Void

    @State private var localInterval: Double

    init(settings: AppSettings,
         onRotateIntervalChanged: @escaping (Double) -> Void) {
        self.settings = settings
        self.onRotateIntervalChanged = onRotateIntervalChanged
        _localInterval = State(initialValue: settings.rotateInterval)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("显示设置")
                .font(.headline)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 8) {
                Text("显示模式")
                    .font(.system(size: 11, weight: .medium))
                Picker("", selection: $settings.displayModeRaw) {
                    Text("单行轮播").tag(DisplayMode.single.rawValue)
                    Text("多行堆叠").tag(DisplayMode.stack.rawValue)
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            }
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 8) {
                Text("轮播间隔: \(Int(localInterval)) 秒")
                    .font(.system(size: 11, weight: .medium))
                Slider(value: $localInterval, in: 1...10, step: 1) {
                    EmptyView()
                }
                .onChange(of: localInterval) { newValue in
                    onRotateIntervalChanged(newValue)
                }
            }
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 8) {
                Toggle("显示涨跌幅", isOn: $settings.showChangePct)
                    .font(.system(size: 11))
            }
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 8) {
                Text("涨跌颜色")
                    .font(.system(size: 11, weight: .medium))
                Picker("", selection: $settings.priceColorModeRaw) {
                    Text("绿涨红跌").tag(PriceColorMode.greenUpRedDown.rawValue)
                    Text("红涨绿跌").tag(PriceColorMode.redUpGreenDown.rawValue)
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            }
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 6) {
                Text("涨跌周期")
                    .font(.system(size: 11, weight: .medium))
                Picker("", selection: $settings.pricePeriodRaw) {
                    Text("UTC+8 当日开盘").tag(PricePeriod.utc8.rawValue)
                    Text("UTC+0 当日开盘").tag(PricePeriod.utc0.rawValue)
                    Text("24 小时滚动").tag(PricePeriod.rolling24h.rawValue)
                }
                .labelsHidden()
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding(.vertical)
    }
}

private struct AboutTab: View {
    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "bitcoinsign.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("币吧 CoinBar")
                .font(.title2)
                .bold()

            Text("版本 1.0.0")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Text("加密货币行情监控")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Text("数据来源: OKX")
                .font(.system(size: 9))
                .foregroundColor(.secondary.opacity(0.6))

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical)
    }
}
