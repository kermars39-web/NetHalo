import AppKit
import Combine

@MainActor
final class DashboardViewController: NSViewController {
    private let model: MetricsStore
    private let settings: SettingsStore
    private let onQuit: () -> Void
    private var cancellables = Set<AnyCancellable>()

    private weak var headerView: HeaderView?
    private weak var networkCard: NetworkCardView?
    private weak var cpuCard: UsageCardView?
    private weak var memoryCard: UsageCardView?
    private weak var networkAppsCard: NetworkAppsCardView?
    private var contentView: NSView?

    init(model: MetricsStore, settings: SettingsStore, onQuit: @escaping () -> Void) {
        self.model = model
        self.settings = settings
        self.onQuit = onQuit
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let effectView = NSVisualEffectView()
        effectView.material = .popover
        effectView.blendingMode = .withinWindow
        effectView.state = .active

        let tintView = BackdropTintView()
        effectView.addSubview(tintView)
        tintView.pinToEdges(of: effectView)

        view = effectView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        showDashboard(animated: false)
        connectUpdates()
    }

    private func connectUpdates() {
        model.$snapshot
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshDashboard() }
            .store(in: &cancellables)

        model.$topNetworkApps
            .receive(on: DispatchQueue.main)
            .sink { [weak self] values in
                guard let self else { return }
                self.networkAppsCard?.update(apps: values, ready: self.model.networkAppsReady)
            }
            .store(in: &cancellables)
    }

    private func refreshDashboard() {
        let snapshot = model.snapshot
        headerView?.update(health: snapshot.health)
        networkCard?.update(
            snapshot: snapshot,
            downloadHistory: model.downloadHistory,
            uploadHistory: model.uploadHistory
        )
        cpuCard?.update(
            value: "\(Int(snapshot.cpuPercent.rounded()))%",
            subtitle: "即时负载",
            history: model.cpuHistory
        )
        memoryCard?.update(
            value: "\(Int(snapshot.memoryPercent.rounded()))%",
            subtitle: "\(MemoryFormatter.gigabytes(snapshot.memoryUsedBytes)) 已用",
            history: model.memoryHistory
        )
    }

    private func install(_ newContent: NSView, animated: Bool) {
        newContent.alphaValue = animated ? 0 : 1
        view.addSubview(newContent)
        newContent.pinToEdges(of: view)

        let previous = contentView
        contentView = newContent

        guard animated else {
            previous?.removeFromSuperview()
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            newContent.animator().alphaValue = 1
            previous?.animator().alphaValue = 0
        } completionHandler: {
            previous?.removeFromSuperview()
        }
    }

    private func showDashboard(animated: Bool) {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let header = HeaderView()
        let network = NetworkCardView()
        let cpu = UsageCardView(title: "CPU", accent: .glanceBlue)
        let memory = UsageCardView(title: "内存", accent: .glanceViolet)
        let networkApps = NetworkAppsCardView()
        let footer = makeFooter()

        headerView = header
        networkCard = network
        cpuCard = cpu
        memoryCard = memory
        networkAppsCard = networkApps

        let usageRow = NSStackView(views: [cpu, memory])
        usageRow.orientation = .horizontal
        usageRow.spacing = 12
        usageRow.distribution = .fillEqually

        let stack = NSStackView(views: [header, network, usageRow, networkApps, footer])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12),
            header.heightAnchor.constraint(equalToConstant: 40),
            network.heightAnchor.constraint(equalToConstant: 136),
            usageRow.heightAnchor.constraint(equalToConstant: 122),
            networkApps.heightAnchor.constraint(equalToConstant: 164),
            footer.heightAnchor.constraint(equalToConstant: 28),
            header.widthAnchor.constraint(equalTo: stack.widthAnchor),
            network.widthAnchor.constraint(equalTo: stack.widthAnchor),
            usageRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            networkApps.widthAnchor.constraint(equalTo: stack.widthAnchor),
            footer.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])

        install(container, animated: animated)
        refreshDashboard()
        networkApps.update(apps: model.topNetworkApps, ready: model.networkAppsReady)
    }

    private func showSettings(animated: Bool) {
        let settingsView = SettingsPanelView(settings: settings)
        settingsView.onBack = { [weak self] in self?.showDashboard(animated: true) }
        install(settingsView, animated: animated)
    }

    private func makeFooter() -> NSView {
        let container = NSView()
        let privacyLabel = makeLabel(
            "仅在本机读取",
            size: 10,
            weight: .medium,
            color: .tertiaryLabelColor
        )

        let settingsButton = makePlainButton(
            title: "设置",
            symbol: "slider.horizontal.3",
            target: self,
            action: #selector(openSettings)
        )
        settingsButton.toolTip = "设置菜单栏显示内容"

        let quitButton = makePlainButton(
            title: "",
            symbol: "power",
            target: self,
            action: #selector(quit)
        )
        quitButton.toolTip = "退出 GlanceBar"

        let buttons = NSStackView(views: [settingsButton, quitButton])
        buttons.orientation = .horizontal
        buttons.spacing = 6
        buttons.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(privacyLabel)
        container.addSubview(buttons)
        privacyLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            privacyLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            privacyLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            buttons.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            buttons.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        return container
    }

    @objc private func openSettings() {
        showSettings(animated: true)
    }

    @objc private func quit() {
        onQuit()
    }
}

// MARK: - Dashboard components

private final class HeaderView: NSView {
    private let healthLabel = PillLabel()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false

        let icon = SymbolBadge(symbol: "waveform.path.ecg", color: .glanceBlue)
        let title = makeLabel("GlanceBar", size: 17, weight: .semibold, color: .labelColor)
        let subtitle = makeLabel("最近一分钟 · 每秒刷新", size: 11, weight: .medium, color: .secondaryLabelColor)

        let titleStack = NSStackView(views: [title, subtitle])
        titleStack.orientation = .vertical
        titleStack.alignment = .leading
        titleStack.spacing = 2

        let stack = NSStackView(views: [icon, titleStack, NSView(), healthLabel])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            icon.widthAnchor.constraint(equalToConstant: 38),
            icon.heightAnchor.constraint(equalToConstant: 38)
        ])

        update(health: .calm)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(health: SystemHealth) {
        let color: NSColor
        switch health {
        case .calm: color = .glanceGreen
        case .working: color = .glanceOrange
        case .busy: color = .systemRed
        }
        healthLabel.update(text: health.title, color: color)
    }
}

private final class NetworkCardView: GlassCardView {
    private let download = NetworkMetricView(title: "下载", symbol: "arrow.down", accent: .glanceCyan)
    private let upload = NetworkMetricView(title: "上传", symbol: "arrow.up", accent: .glanceBlue)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        let title = makeLabel("网络流动", size: 12, weight: .semibold, color: .secondaryLabelColor)
        let symbol = makeSymbol("arrow.up.arrow.down", size: 11, weight: .semibold, color: .tertiaryLabelColor)
        let header = NSStackView(views: [title, NSView(), symbol])
        header.orientation = .horizontal
        header.alignment = .centerY

        let divider = NSBox()
        divider.boxType = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false

        let metrics = NSStackView(views: [download, divider, upload])
        metrics.orientation = .horizontal
        metrics.alignment = .centerY
        metrics.spacing = 16
        metrics.distribution = .fill

        let stack = NSStackView(views: [header, metrics])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
            header.widthAnchor.constraint(equalTo: stack.widthAnchor),
            metrics.widthAnchor.constraint(equalTo: stack.widthAnchor),
            divider.widthAnchor.constraint(equalToConstant: 1),
            divider.heightAnchor.constraint(equalToConstant: 72),
            download.widthAnchor.constraint(equalTo: upload.widthAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(snapshot: MetricsSnapshot, downloadHistory: [Double], uploadHistory: [Double]) {
        download.update(value: RateFormatter.detail(snapshot.downloadBytesPerSecond), history: downloadHistory)
        upload.update(value: RateFormatter.detail(snapshot.uploadBytesPerSecond), history: uploadHistory)
    }
}

private final class NetworkMetricView: NSView {
    private let valueLabel = makeLabel("0 KB/s", size: 21, weight: .semibold, color: .labelColor, monospaced: true)
    private let sparkline: SparklineView

    init(title: String, symbol: String, accent: NSColor) {
        sparkline = SparklineView(accent: accent)
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = makeLabel(title, size: 11, weight: .semibold, color: accent)
        let icon = makeSymbol(symbol, size: 10, weight: .semibold, color: accent)
        let titleRow = NSStackView(views: [icon, titleLabel, NSView()])
        titleRow.orientation = .horizontal
        titleRow.alignment = .centerY
        titleRow.spacing = 5

        valueLabel.lineBreakMode = .byClipping
        valueLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let stack = NSStackView(views: [titleRow, valueLabel, sparkline])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            titleRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            sparkline.widthAnchor.constraint(equalTo: stack.widthAnchor),
            sparkline.heightAnchor.constraint(equalToConstant: 32)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(value: String, history: [Double]) {
        valueLabel.stringValue = value
        sparkline.values = history
    }
}

private final class UsageCardView: GlassCardView {
    private let valueLabel = makeLabel("0%", size: 25, weight: .semibold, color: .labelColor, monospaced: true)
    private let subtitleLabel = makeLabel("", size: 10, weight: .medium, color: .tertiaryLabelColor)
    private let sparkline: SparklineView

    init(title: String, accent: NSColor) {
        sparkline = SparklineView(accent: accent, fixedMaximum: 100)
        super.init(frame: .zero)

        let titleLabel = makeLabel(title, size: 11, weight: .semibold, color: .secondaryLabelColor)
        let dot = ColorDot(color: accent)
        let header = NSStackView(views: [titleLabel, NSView(), dot])
        header.orientation = .horizontal
        header.alignment = .centerY

        let stack = NSStackView(views: [header, valueLabel, sparkline, subtitleLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            header.widthAnchor.constraint(equalTo: stack.widthAnchor),
            sparkline.widthAnchor.constraint(equalTo: stack.widthAnchor),
            sparkline.heightAnchor.constraint(equalToConstant: 23),
            dot.widthAnchor.constraint(equalToConstant: 6),
            dot.heightAnchor.constraint(equalToConstant: 6)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(value: String, subtitle: String, history: [Double]) {
        valueLabel.stringValue = value
        subtitleLabel.stringValue = subtitle
        sparkline.values = history
    }
}

private final class NetworkAppsCardView: GlassCardView {
    private let rows = NSStackView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        let title = makeLabel("网络占用", size: 12, weight: .semibold, color: .secondaryLabelColor)
        let speed = makeLabel("实时速度", size: 9, weight: .semibold, color: .tertiaryLabelColor)
        let header = NSStackView(views: [title, NSView(), speed])
        header.orientation = .horizontal
        header.alignment = .centerY

        rows.orientation = .vertical
        rows.alignment = .leading
        rows.spacing = 4

        let stack = NSStackView(views: [header, rows])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 11),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -8),
            header.widthAnchor.constraint(equalTo: stack.widthAnchor),
            rows.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])

        update(apps: [], ready: false)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(apps: [NetworkAppMetric], ready: Bool) {
        for view in rows.arrangedSubviews {
            rows.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        guard !apps.isEmpty else {
            let message = ready ? "当前没有明显联网应用" : "正在读取应用网速…"
            let label = makeLabel(message, size: 11, weight: .medium, color: .secondaryLabelColor)
            let row: NSStackView
            if ready {
                let icon = makeSymbol("network.slash", size: 12, weight: .medium, color: .tertiaryLabelColor)
                row = NSStackView(views: [icon, label])
            } else {
                let progress = NSProgressIndicator()
                progress.style = .spinning
                progress.controlSize = .small
                progress.startAnimation(nil)
                row = NSStackView(views: [progress, label])
            }
            row.orientation = .horizontal
            row.alignment = .centerY
            row.spacing = 8
            row.heightAnchor.constraint(equalToConstant: 90).isActive = true
            rows.addArrangedSubview(row)
            return
        }

        for app in apps.prefix(4) {
            let row = NetworkAppRowView(app: app)
            rows.addArrangedSubview(row)
            row.heightAnchor.constraint(equalToConstant: 25).isActive = true
            row.widthAnchor.constraint(equalTo: rows.widthAnchor).isActive = true
        }
    }
}

private final class NetworkAppRowView: NSView {
    init(app: NetworkAppMetric) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let initial = String(app.name.prefix(1)).uppercased()
        let badge = InitialBadge(text: initial)
        let name = makeLabel(app.name, size: 11, weight: .medium, color: .labelColor)
        name.lineBreakMode = .byTruncatingTail

        let down = makeLabel("↓ \(RateFormatter.menu(app.downloadBytesPerSecond))/s", size: 9, weight: .semibold, color: .glanceCyan, monospaced: true)
        let up = makeLabel("↑ \(RateFormatter.menu(app.uploadBytesPerSecond))/s", size: 9, weight: .semibold, color: .glanceBlue, monospaced: true)
        down.alignment = .right
        up.alignment = .right
        let rates = NSStackView(views: [down, up])
        rates.orientation = .vertical
        rates.alignment = .trailing
        rates.spacing = 1

        let stack = NSStackView(views: [badge, name, NSView(), rates])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 9
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            badge.widthAnchor.constraint(equalToConstant: 25),
            badge.heightAnchor.constraint(equalToConstant: 25),
            rates.widthAnchor.constraint(greaterThanOrEqualToConstant: 72)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - Settings

private final class SettingsPanelView: NSView {
    var onBack: (() -> Void)?
    private let settings: SettingsStore
    private let launchError = makeLabel("", size: 10, weight: .medium, color: .glanceOrange)

    init(settings: SettingsStore) {
        self.settings = settings
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        build()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func build() {
        let back = makePlainButton(title: "", symbol: "chevron.left", target: self, action: #selector(goBack))
        back.toolTip = "返回状态面板"
        let title = makeLabel("设置", size: 18, weight: .semibold, color: .labelColor)
        let subtitle = makeLabel("保持简洁，不打扰菜单栏", size: 11, weight: .medium, color: .secondaryLabelColor)
        let titleStack = NSStackView(views: [title, subtitle])
        titleStack.orientation = .vertical
        titleStack.alignment = .leading
        titleStack.spacing = 2
        let header = NSStackView(views: [back, titleStack, NSView()])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 10

        let menuIcon = makeSymbol("arrow.up.arrow.down", size: 13, weight: .semibold, color: .glanceBlue)
        let menuTitle = makeLabel("菜单栏只显示网速", size: 12, weight: .semibold, color: .labelColor)
        let menuSubtitle = makeLabel("下载与上传纵向排列，宽度固定，不会随数字晃动", size: 10, weight: .regular, color: .secondaryLabelColor)
        let menuLabels = NSStackView(views: [menuTitle, menuSubtitle])
        menuLabels.orientation = .vertical
        menuLabels.alignment = .leading
        menuLabels.spacing = 2
        let menuSummary = NSStackView(views: [menuIcon, menuLabels, NSView()])
        menuSummary.orientation = .horizontal
        menuSummary.alignment = .centerY
        menuSummary.spacing = 10
        menuSummary.heightAnchor.constraint(equalToConstant: 54).isActive = true
        let menuCard = wrapInCard(menuSummary, horizontalPadding: 14)

        let launchRow = ToggleRow(
            title: "开机自动启动",
            subtitle: "登录后自动出现在菜单栏",
            symbol: "power",
            isOn: settings.launchAtLogin,
            onChange: { [weak self] enabled in
                self?.settings.setLaunchAtLogin(enabled)
                self?.launchError.stringValue = self?.settings.launchError ?? ""
            }
        )
        let launchCard = wrapInCard(launchRow, horizontalPadding: 14)
        launchError.lineBreakMode = .byWordWrapping
        launchError.maximumNumberOfLines = 2

        let privacyTitle = makeLabel("关于数据", size: 12, weight: .semibold, color: .labelColor)
        let privacyIcon = makeSymbol("lock.shield", size: 12, weight: .semibold, color: .glanceBlue)
        let privacyHeader = NSStackView(views: [privacyIcon, privacyTitle, NSView()])
        privacyHeader.orientation = .horizontal
        privacyHeader.spacing = 7
        let privacyText = makeLabel(
            "GlanceBar 仅在本机读取系统公开统计信息，不需要管理员权限，不上传数据，也不会扫描文件内容。",
            size: 11,
            weight: .regular,
            color: .secondaryLabelColor
        )
        privacyText.lineBreakMode = .byWordWrapping
        privacyText.maximumNumberOfLines = 0
        let privacyStack = NSStackView(views: [privacyHeader, privacyText])
        privacyStack.orientation = .vertical
        privacyStack.alignment = .leading
        privacyStack.spacing = 8
        let privacyCard = wrapInCard(privacyStack, horizontalPadding: 16)

        let about = makeLabel("GlanceBar 0.1 · 原生 macOS", size: 10, weight: .medium, color: .tertiaryLabelColor)
        about.alignment = .center

        let stack = NSStackView(views: [header, menuCard, launchCard, launchError, privacyCard, NSView(), about])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -18),
            header.widthAnchor.constraint(equalTo: stack.widthAnchor),
            menuCard.widthAnchor.constraint(equalTo: stack.widthAnchor),
            launchCard.widthAnchor.constraint(equalTo: stack.widthAnchor),
            launchError.widthAnchor.constraint(equalTo: stack.widthAnchor),
            privacyCard.widthAnchor.constraint(equalTo: stack.widthAnchor),
            about.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }

    private func wrapInCard(_ content: NSView, horizontalPadding: CGFloat) -> GlassCardView {
        let card = GlassCardView()
        card.addSubview(content)
        content.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: horizontalPadding),
            content.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -horizontalPadding),
            content.topAnchor.constraint(equalTo: card.topAnchor, constant: 4),
            content.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -4)
        ])
        return card
    }

    private func separator() -> NSView {
        let box = NSBox()
        box.boxType = .separator
        box.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return box
    }

    @objc private func goBack() {
        onBack?()
    }
}

private final class ToggleRow: NSView {
    private let onChange: (Bool) -> Void
    private let toggle = NSSwitch()

    init(title: String, subtitle: String, symbol: String, isOn: Bool, onChange: @escaping (Bool) -> Void) {
        self.onChange = onChange
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let icon = makeSymbol(symbol, size: 13, weight: .semibold, color: .glanceBlue)
        icon.frame.size = NSSize(width: 24, height: 18)
        let titleLabel = makeLabel(title, size: 12, weight: .semibold, color: .labelColor)
        let subtitleLabel = makeLabel(subtitle, size: 10, weight: .regular, color: .secondaryLabelColor)
        let labels = NSStackView(views: [titleLabel, subtitleLabel])
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 2

        toggle.state = isOn ? .on : .off
        toggle.controlSize = .small
        toggle.target = self
        toggle.action = #selector(changed)

        let stack = NSStackView(views: [icon, labels, NSView(), toggle])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 54),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            icon.widthAnchor.constraint(equalToConstant: 24)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func changed() {
        onChange(toggle.state == .on)
    }
}

// MARK: - Drawing and shared UI

private class GlassCardView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.055
        layer?.shadowRadius = 14
        layer?.shadowOffset = CGSize(width: 0, height: -5)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(roundedRect: rect, xRadius: 18, yRadius: 18)
        NSColor.controlBackgroundColor.withAlphaComponent(0.62).setFill()
        path.fill()
        NSColor.white.withAlphaComponent(0.20).setStroke()
        path.lineWidth = 0.8
        path.stroke()
    }
}

private final class SparklineView: NSView {
    var values: [Double] = [] { didSet { needsDisplay = true } }
    private let accent: NSColor
    private let fixedMaximum: Double?

    init(accent: NSColor, fixedMaximum: Double? = nil) {
        self.accent = accent
        self.fixedMaximum = fixedMaximum
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard values.count > 1, bounds.width > 0, bounds.height > 0 else {
            let baseline = NSBezierPath()
            baseline.move(to: NSPoint(x: 0, y: bounds.midY))
            baseline.line(to: NSPoint(x: bounds.maxX, y: bounds.midY))
            accent.withAlphaComponent(0.18).setStroke()
            baseline.lineWidth = 2
            baseline.stroke()
            return
        }

        let maximum = max(1, fixedMaximum ?? values.max() ?? 1)
        let xStep = bounds.width / CGFloat(values.count - 1)
        let path = NSBezierPath()
        path.lineWidth = 2
        path.lineCapStyle = .round
        path.lineJoinStyle = .round

        for (index, value) in values.enumerated() {
            let ratio = min(1, max(0, value / maximum))
            let point = NSPoint(
                x: CGFloat(index) * xStep,
                y: 1 + CGFloat(ratio) * (bounds.height - 2)
            )
            index == 0 ? path.move(to: point) : path.line(to: point)
        }

        accent.setStroke()
        path.stroke()
    }
}

private final class BackdropTintView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let dark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let start = dark ? NSColor.black.withAlphaComponent(0.10) : NSColor.white.withAlphaComponent(0.42)
        let end = NSColor.glanceBlue.withAlphaComponent(dark ? 0.055 : 0.035)
        NSGradient(starting: start, ending: end)?.draw(in: bounds, angle: -45)
    }
}

private final class SymbolBadge: NSView {
    init(symbol: String, color: NSColor) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 19
        layer?.backgroundColor = color.withAlphaComponent(0.11).cgColor

        let image = makeSymbol(symbol, size: 16, weight: .semibold, color: color)
        addSubview(image)
        image.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            image.centerXAnchor.constraint(equalTo: centerXAnchor),
            image.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

private final class PillLabel: NSView {
    private let label = makeLabel("", size: 10, weight: .semibold, color: .labelColor)
    private let dot = ColorDot(color: .glanceGreen)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 13

        let stack = NSStackView(views: [dot, label])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 9),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -9),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            dot.widthAnchor.constraint(equalToConstant: 6),
            dot.heightAnchor.constraint(equalToConstant: 6)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(text: String, color: NSColor) {
        label.stringValue = text
        label.textColor = color
        dot.color = color
        layer?.backgroundColor = color.withAlphaComponent(0.09).cgColor
    }
}

private final class ColorDot: NSView {
    var color: NSColor { didSet { layer?.backgroundColor = color.cgColor } }

    init(color: NSColor) {
        self.color = color
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 3
        layer?.backgroundColor = color.cgColor
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

private final class InitialBadge: NSView {
    init(text: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 7
        layer?.backgroundColor = NSColor.glanceBlue.withAlphaComponent(0.10).cgColor

        let label = makeLabel(text, size: 9, weight: .bold, color: .glanceBlue)
        label.alignment = .center
        addSubview(label)
        label.pinToEdges(of: self)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

private func makeLabel(
    _ text: String,
    size: CGFloat,
    weight: NSFont.Weight,
    color: NSColor,
    monospaced: Bool = false
) -> NSTextField {
    let label = NSTextField(labelWithString: text)
    label.font = monospaced
        ? NSFont.monospacedDigitSystemFont(ofSize: size, weight: weight)
        : NSFont.systemFont(ofSize: size, weight: weight)
    label.textColor = color
    label.drawsBackground = false
    label.isBezeled = false
    label.isEditable = false
    label.isSelectable = false
    return label
}

private func makeSymbol(
    _ name: String,
    size: CGFloat,
    weight: NSFont.Weight,
    color: NSColor
) -> NSImageView {
    let configuration = NSImage.SymbolConfiguration(pointSize: size, weight: weight)
    let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
        .withSymbolConfiguration(configuration)
    let view = NSImageView(image: image ?? NSImage())
    view.contentTintColor = color
    view.imageScaling = .scaleProportionallyDown
    return view
}

private func makePlainButton(
    title: String,
    symbol: String,
    target: AnyObject,
    action: Selector
) -> NSButton {
    let button = NSButton(title: title, target: target, action: action)
    button.isBordered = false
    button.font = .systemFont(ofSize: 10, weight: .semibold)
    button.contentTintColor = .secondaryLabelColor
    if let image = NSImage(systemSymbolName: symbol, accessibilityDescription: title) {
        button.image = image.withSymbolConfiguration(.init(pointSize: 11, weight: .semibold))
        button.imagePosition = title.isEmpty ? .imageOnly : .imageLeading
    }
    return button
}

private extension NSView {
    func pinToEdges(of parent: NSView) {
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: parent.leadingAnchor),
            trailingAnchor.constraint(equalTo: parent.trailingAnchor),
            topAnchor.constraint(equalTo: parent.topAnchor),
            bottomAnchor.constraint(equalTo: parent.bottomAnchor)
        ])
    }
}

private extension NSColor {
    static let glanceBlue = NSColor(calibratedRed: 0.12, green: 0.47, blue: 0.96, alpha: 1)
    static let glanceCyan = NSColor(calibratedRed: 0.02, green: 0.69, blue: 0.74, alpha: 1)
    static let glanceViolet = NSColor(calibratedRed: 0.53, green: 0.36, blue: 0.96, alpha: 1)
    static let glanceGreen = NSColor(calibratedRed: 0.12, green: 0.68, blue: 0.42, alpha: 1)
    static let glanceOrange = NSColor(calibratedRed: 0.96, green: 0.51, blue: 0.14, alpha: 1)
}
