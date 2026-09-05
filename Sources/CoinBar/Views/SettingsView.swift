import SwiftUI

struct SettingsView: View {
    @ObservedObject var priceStore: PriceStore

    var body: some View {
        TabView {
            CoinSettingsTab(settings: priceStore.settings)
                .tabItem { Label("币种", systemImage: "bitcoinsign.circle") }

            PriceAlertsTab(settings: priceStore.settings, priceStore: priceStore)
                .tabItem { Label("预警", systemImage: "bell.fill") }

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

/// 设置卡片容器（在「显示」/「预警」Tab 间共用）
@ViewBuilder
fileprivate func SettingsCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
    content()
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
        .padding(.horizontal)
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
                    Text("输入基础币符号（如 GRAM），计价币可选 USDT/USDC")
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
        VStack(spacing: 14) {
            Text("显示设置")
                .font(.system(size: 14, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

            SettingsCard {
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

            SettingsCard {
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

            SettingsCard {
                Toggle(isOn: $settings.showChangePct) {
                    Label("显示涨跌幅", systemImage: "percent")
                        .font(.system(size: 11, weight: .semibold))
                }
            }

            SettingsCard {
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

            SettingsCard {
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

    private var periodDescription: String {
        switch settings.pricePeriod {
        case .utc8: return "以 UTC+8 当日开盘价为基准"
        case .utc0: return "以 UTC+0 当日开盘价为基准"
        case .rolling24h: return "以 24 小时滚动开盘价为基准"
        }
    }
}

// MARK: - 预警管理

private struct PriceAlertsTab: View {
    @ObservedObject var settings: AppSettings
    /// 通过 PriceStore 操作以同步清理 AlertEngine 运行态
    var priceStore: PriceStore

    @State private var editing: PriceAlert?
    @State private var showCreate = false

    var body: some View {
        VStack(spacing: 0) {
            // 操作栏
            HStack(spacing: 8) {
                Text("预警规则 \(settings.alerts.count)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Spacer()
                Toggle("", isOn: $settings.alertsEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .help("全局预警总开关")
                Text(settings.alertsEnabled ? "已启用" : "已暂停")
                    .font(.system(size: 10))
                    .foregroundColor(settings.alertsEnabled ? .accentColor : .secondary)
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider().opacity(0.3).padding(.horizontal, 8)

            List {
                if settings.alerts.isEmpty {
                    Section {
                        HStack {
                            Spacer()
                            Text("尚未添加预警")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.vertical, 12)
                    }
                } else {
                    Section {
                        ForEach(settings.alerts) { alert in
                            alertRow(alert)
                        }
                    } header: {
                        sectionHeader("生效中", count: settings.alerts.count)
                    }
                }
            }
            .listStyle(.sidebar)

            Divider().opacity(0.3)

            // 新建预警
            HStack {
                Spacer()
                Button {
                    showCreate = true
                } label: {
                    Label("新建预警", systemImage: "plus.circle.fill")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
                Spacer()
            }
            .padding(12)
        }
        .sheet(isPresented: $showCreate) {
            AlertEditor(mode: .create, settings: settings) { newAlert in
                priceStore.addAlert(newAlert)
                Task { await NotificationService.shared.requestAuthorizationIfNeeded() }
            }
        }
        .sheet(item: $editing) { alert in
            AlertEditor(mode: .edit(alert), settings: settings) { updated in
                priceStore.updateAlert(updated)
            }
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
    private func alertRow(_ alert: PriceAlert) -> some View {
        let symbol = settings.allCoins.first(where: { $0.instId == alert.instId })?.symbol
            ?? alert.instId.split(separator: "-").first.map(String.init) ?? alert.instId

        HStack(spacing: 8) {
            Toggle("", isOn: Binding(
                get: { alert.enabled },
                set: { newValue in
                    var updated = alert
                    updated.enabled = newValue
                    priceStore.updateAlert(updated)
                }
            ))
            .toggleStyle(.switch)
            .labelsHidden()

            VStack(alignment: .leading, spacing: 2) {
                Text(alert.conditionDescription(symbol: symbol))
                    .font(.system(size: 12, weight: .medium))
                if let note = alert.note, !note.isEmpty {
                    Text(note)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button {
                editing = alert
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.7))
            }
            .buttonStyle(.plain)
            .help("编辑")

            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    priceStore.removeAlert(id: alert.id)
                }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .buttonStyle(.plain)
            .help("删除")
        }
        .contentShape(Rectangle())
        .onTapGesture { editing = alert }
    }
}

/// 预警新建/编辑表单（Sheet）
private struct AlertEditor: View {
    enum Mode {
        case create
        case edit(PriceAlert)
    }

    let mode: Mode
    let settings: AppSettings
    let onSubmit: (PriceAlert) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var instId: String = ""
    @State private var type: AlertType = .price
    @State private var direction: AlertDirection = .up
    @State private var thresholdText: String = ""
    @State private var note: String = ""
    @State private var error: String?

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text(mode.isEdit ? "编辑预警" : "新建预警")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button("取消") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.top, 16)

            Form {
                Section("币种") {
                    Picker("币种", selection: $instId) {
                        ForEach(settings.allCoins) { coin in
                            Text(coin.instId).tag(coin.instId)
                        }
                    }
                }

                Section("条件") {
                    Picker("类型", selection: $type) {
                        Text("价格").tag(AlertType.price)
                        Text("涨跌幅").tag(AlertType.changePct)
                    }
                    .pickerStyle(.segmented)

                    Picker("方向", selection: $direction) {
                        Text(type == .price ? "涨破 ≥" : "涨幅 ≥").tag(AlertDirection.up)
                        Text(type == .price ? "跌破 ≤" : "跌幅 ≥").tag(AlertDirection.down)
                    }
                    .pickerStyle(.segmented)

                    HStack {
                        Text(thresholdLabel)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        TextField(thresholdPlaceholder, text: $thresholdText)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                Section("备注（可选）") {
                    TextField("例如：关注关键阻力位", text: $note)
                }

                if let error {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.system(size: 11))
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button(mode.isEdit ? "保存" : "添加") { submit() }
                    .buttonStyle(.borderedProminent)
                    .disabled(instId.isEmpty)
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
        .frame(width: 360, height: 460)
        .onAppear(perform: loadInitial)
    }

    private var thresholdLabel: String {
        switch type {
        case .price: return "价格阈值"
        case .changePct: return "百分比（%）"
        }
    }

    private var thresholdPlaceholder: String {
        switch type {
        case .price: return "如 100000"
        case .changePct: return "如 5"
        }
    }

    private func loadInitial() {
        switch mode {
        case .create:
            instId = settings.allCoins.first?.instId ?? ""
        case .edit(let alert):
            instId = alert.instId
            type = alert.type
            direction = alert.direction
            thresholdText = String(alert.threshold)
            note = alert.note ?? ""
        }
    }

    private func submit() {
        let trimmed = thresholdText.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard let value = Double(trimmed) else {
            error = "阈值需为数字"
            return
        }
        switch type {
        case .price:
            guard value > 0 else { error = "价格阈值必须大于 0"; return }
        case .changePct:
            guard value >= 0, value <= 100 else { error = "百分比阈值需在 0–100 之间"; return }
        }

        let id: UUID = {
            if case .edit(let alert) = mode { return alert.id }
            return UUID()
        }()
        let noteValue = note.trimmingCharacters(in: .whitespaces)
        let alert = PriceAlert(
            id: id,
            instId: instId,
            type: type,
            direction: direction,
            threshold: value,
            enabled: true,
            note: noteValue.isEmpty ? nil : noteValue
        )
        onSubmit(alert)
        dismiss()
    }
}

private extension AlertEditor.Mode {
    var isEdit: Bool {
        if case .edit = self { return true }
        return false
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

            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
               let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                Text("版本 \(version) (\(build))")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

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
