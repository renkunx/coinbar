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
            .tabItem { Label("显示", systemImage: "slider.horizontal.3") }

            AboutTab()
                .tabItem { Label("关于", systemImage: "info.circle") }
        }
        .frame(width: 420, height: 560)
    }
}

// MARK: - 币种管理

private struct CoinSettingsTab: View {
    @ObservedObject var settings: AppSettings

    @State private var searchText: String = ""
    @State private var newBaseSymbol: String = ""
    @State private var newQuoteCoin: String = "USDT"
    @State private var addError: String?

    private let quoteOptions = ["USDT", "USDC"]

    private var filteredCoins: [Coin] {
        let all = settings.allCoins
        guard !searchText.isEmpty else { return all }
        return all.filter {
            $0.symbol.localizedCaseInsensitiveContains(searchText)
                || $0.instId.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var enabledFiltered: [Coin] {
        filteredCoins.filter { settings.enabledInstIds.contains($0.instId) }
    }

    private var availableFiltered: [Coin] {
        filteredCoins.filter { !settings.enabledInstIds.contains($0.instId) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 搜索栏
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("搜索币种", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.1))
            )
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // 操作栏
            HStack(spacing: 8) {
                Text("全部币种 \(settings.allCoins.count)　已启用 \(settings.enabledInstIds.count)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Spacer()
                Button("全选") { settings.enabledInstIds = settings.allCoins.map(\.instId) }
                    .font(.system(size: 10))
                Button("默认") { settings.resetCoinsToDefault(); settings.enabledInstIds = AppSettings.defaultCoins.prefix(4).map(\.instId) }
                    .font(.system(size: 10))
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            Divider().opacity(0.3).padding(.horizontal, 8)

            // 币种列表
            List {
                if !enabledFiltered.isEmpty {
                    Section {
                        ForEach(enabledFiltered) { coin in
                            coinRow(coin, isEnabled: true)
                        }
                    } header: {
                        sectionHeader("已启用", count: enabledFiltered.count)
                    }
                }

                if !availableFiltered.isEmpty {
                    Section {
                        ForEach(availableFiltered) { coin in
                            coinRow(coin, isEnabled: false)
                        }
                    } header: {
                        sectionHeader("可用币种", count: availableFiltered.count)
                    }
                }

                if filteredCoins.isEmpty {
                    Section {
                        HStack {
                            Spacer()
                            Text(searchText.isEmpty ? "暂无币种" : "无匹配结果")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.vertical, 12)
                    }
                }
            }
            .listStyle(.sidebar)

            Divider().opacity(0.3)

            // 添加自定义币种
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("＋ 添加自定义币种")
                        .font(.system(size: 11, weight: .semibold))
                    Spacer()
                }

                HStack(spacing: 6) {
                    TextField("基础币", text: $newBaseSymbol)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 8)
                        .frame(height: 26)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.secondary.opacity(0.1))
                        )
                        .onChange(of: newBaseSymbol) { newValue in
                            newBaseSymbol = newValue.filter { $0.isLetter || $0.isNumber }.uppercased()
                        }

                    Picker("", selection: $newQuoteCoin) {
                        ForEach(quoteOptions, id: \.self) { Text($0) }
                    }
                    .labelsHidden()
                    .frame(width: 80)

                    Button {
                        addCoin()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                    .disabled(newBaseSymbol.isEmpty)
                }

                if let addError {
                    Text(addError)
                        .font(.system(size: 9))
                        .foregroundColor(.red)
                } else {
                    Text("输入基础币符号（如 TON），计价币可选 USDT/USDC")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary.opacity(0.8))
                }
            }
            .padding(12)
        }
    }

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
            Text("\(count)")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private func coinRow(_ coin: Coin, isEnabled: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isEnabled ? .accentColor : .secondary.opacity(0.5))
                .font(.system(size: 12))

            Text(coin.symbol)
                .font(.system(size: 12, weight: .medium))

            Text(coin.instId)
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    settings.removeCoin(instId: coin.instId)
                }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .buttonStyle(.plain)
            .help("删除此币种")
        }
        .contentShape(Rectangle())
        .onTapGesture {
            toggle(coin.instId, isEnabled: isEnabled)
        }
    }

    private func toggle(_ instId: String, isEnabled: Bool) {
        if isEnabled {
            settings.enabledInstIds.removeAll { $0 == instId }
        } else {
            if !settings.enabledInstIds.contains(instId) {
                settings.enabledInstIds.append(instId)
            }
        }
    }

    private func addCoin() {
        let base = newBaseSymbol.trimmingCharacters(in: .whitespaces).uppercased()
        guard !base.isEmpty else {
            addError = "请输入基础币符号"
            return
        }
        let ok = settings.addCoin(baseSymbol: base, quoteCoin: newQuoteCoin)
        if ok {
            newBaseSymbol = ""
            addError = nil
        } else {
            addError = "\(base)-\(newQuoteCoin) 已存在"
        }
    }
}

// MARK: - 显示设置

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
        ScrollView {
            VStack(spacing: 14) {
                Text("显示设置")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                // 显示模式
                settingsCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("显示模式", systemImage: "rectangle.split.3x1")
                            .font(.system(size: 11, weight: .semibold))
                        Picker("", selection: $settings.displayModeRaw) {
                            Text("单行轮播").tag(DisplayMode.single.rawValue)
                            Text("多行堆叠").tag(DisplayMode.stack.rawValue)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        Text(settings.displayMode == .single ? "逐个轮播展示已启用币种" : "同时堆叠展示多个币种")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }

                // 轮播间隔
                settingsCard {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("轮播间隔", systemImage: "timer")
                                .font(.system(size: 11, weight: .semibold))
                            Spacer()
                            Text("\(Int(localInterval)) 秒")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(.accentColor)
                        }
                        Slider(value: $localInterval, in: 1...10, step: 1)
                            .onChange(of: localInterval) { newValue in
                                onRotateIntervalChanged(newValue)
                            }
                    }
                }

                // 显示涨跌
                settingsCard {
                    Toggle(isOn: $settings.showChangePct) {
                        Label("显示涨跌幅", systemImage: "percent")
                            .font(.system(size: 11, weight: .semibold))
                    }
                }

                // 涨跌颜色
                settingsCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("涨跌颜色", systemImage: "paintpalette")
                            .font(.system(size: 11, weight: .semibold))
                        Picker("", selection: $settings.priceColorModeRaw) {
                            Text("绿涨红跌").tag(PriceColorMode.greenUpRedDown.rawValue)
                            Text("红涨绿跌").tag(PriceColorMode.redUpGreenDown.rawValue)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
                }

                // 涨跌周期
                settingsCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("涨跌周期", systemImage: "calendar")
                            .font(.system(size: 11, weight: .semibold))
                        Picker("", selection: $settings.pricePeriodRaw) {
                            Text("UTC+8").tag(PricePeriod.utc8.rawValue)
                            Text("UTC+0").tag(PricePeriod.utc0.rawValue)
                            Text("24H").tag(PricePeriod.rolling24h.rawValue)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        Text(periodDescription)
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }
            .padding(.vertical, 12)
        }
    }

    private var periodDescription: String {
        switch settings.pricePeriod {
        case .utc8: return "以 UTC+8 当日开盘价为基准"
        case .utc0: return "以 UTC+0 当日开盘价为基准"
        case .rolling24h: return "以 24 小时滚动开盘价为基准"
        }
    }

    private func settingsCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.secondary.opacity(0.08))
            )
            .padding(.horizontal)
    }
}

// MARK: - 关于

private struct AboutTab: View {
    var body: some View {
        VStack(spacing: 14) {
            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 14)
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
                    .frame(width: 64, height: 64)
                Image(systemName: "bitcoinsign")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
            }

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
