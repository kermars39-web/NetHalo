import AppKit
import Combine

@MainActor
final class DashboardViewController: NSViewController {
    static let panelSize = NSSize(width: 342, height: 471)
    static let shadowInsets = NSEdgeInsets(top: 0, left: 20, bottom: 24, right: 20)
    static let windowSize = NSSize(
        width: panelSize.width + shadowInsets.left + shadowInsets.right,
        height: panelSize.height + shadowInsets.top + shadowInsets.bottom
    )

    private let model: MetricsStore
    private let settings: SettingsStore
    private let onQuit: () -> Void
    private var cancellables = Set<AnyCancellable>()

    private weak var networkCard: NetworkCardView?
    private weak var cpuCard: UsageCardView?
    private weak var memoryCard: UsageCardView?
    private weak var appUsageCard: AppUsageCardView?
    private var contentHostView: NSView!
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
        let rootFrame = NSRect(origin: .zero, size: Self.windowSize)
        let surfaceFrame = NSRect(
            x: Self.shadowInsets.left,
            y: Self.shadowInsets.bottom,
            width: Self.panelSize.width,
            height: Self.panelSize.height
        )
        let rootView = PanelRootView(frame: rootFrame, interactiveFrame: surfaceFrame)
        let shadowHost = RoundedPanelShadowView(frame: surfaceFrame)
        rootView.addSubview(shadowHost)

        let glassFrame = NSRect(origin: .zero, size: Self.panelSize)
        let contentHost = NSView(frame: glassFrame)
        contentHost.autoresizingMask = [.width, .height]
        contentHostView = contentHost

        if #available(macOS 26.0, *) {
            let glassView = NSGlassEffectView(frame: glassFrame)
            glassView.autoresizingMask = [.width, .height]
            glassView.style = .regular
            glassView.cornerRadius = 20
            glassView.wantsLayer = true
            glassView.layer?.cornerRadius = 20
            glassView.layer?.cornerCurve = .continuous
            glassView.layer?.masksToBounds = true
            glassView.contentView = contentHost
            if #available(macOS 27.0, *) {
                glassView.effectIsInteractive = false
            }
            shadowHost.addSubview(glassView)
        } else {
            let effectView = NSVisualEffectView(frame: glassFrame)
            effectView.autoresizingMask = [.width, .height]
            effectView.material = .popover
            effectView.blendingMode = .behindWindow
            effectView.state = .active
            effectView.wantsLayer = true
            effectView.layer?.cornerRadius = 20
            effectView.layer?.cornerCurve = .continuous
            effectView.layer?.masksToBounds = true
            effectView.addSubview(contentHost)
            shadowHost.addSubview(effectView)
        }
        let rimView = RoundedPanelRimView(frame: glassFrame)
        rimView.autoresizingMask = [.width, .height]
        shadowHost.addSubview(rimView)
        view = rootView
        preferredContentSize = Self.windowSize
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
            .sink { [weak self] _ in self?.refreshAppUsage() }
            .store(in: &cancellables)

        model.$topCPUApps
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshAppUsage() }
            .store(in: &cancellables)

        model.$topMemoryApps
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshAppUsage() }
            .store(in: &cancellables)

        settings.$selectedDetailMetric
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshAppUsage() }
            .store(in: &cancellables)
    }

    private func refreshDashboard() {
        let snapshot = model.snapshot
        networkCard?.update(
            snapshot: snapshot,
            downloadHistory: model.downloadHistory,
            uploadHistory: model.uploadHistory
        )
        cpuCard?.update(
            value: "\(Int(snapshot.cpuPercent.rounded()))%",
            caption: "即时负载",
            history: model.cpuHistory
        )
        memoryCard?.update(
            value: "\(Int(snapshot.memoryPercent.rounded()))%",
            caption: "\(MemoryFormatter.gigabytes(snapshot.memoryUsedBytes)) 已用",
            history: model.memoryHistory
        )
    }

    private func refreshAppUsage() {
        let selected = settings.selectedDetailMetric
        networkCard?.setMetricSelected(selected == .network)
        cpuCard?.setMetricSelected(selected == .cpu)
        memoryCard?.setMetricSelected(selected == .memory)
        appUsageCard?.update(
            metric: selected,
            networkApps: model.topNetworkApps,
            processApps: selected == .cpu ? model.topCPUApps : model.topMemoryApps,
            ready: selected == .network ? model.networkAppsReady : model.resourceAppsReady
        )
    }

    private func install(_ newContent: NSView, animated: Bool) {
        preferredContentSize = Self.windowSize
        newContent.alphaValue = animated ? 0 : 1
        contentHostView.addSubview(newContent)
        newContent.pinToEdges(of: contentHostView)

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

        let network = NetworkCardView()
        let cpu = UsageCardView(title: "CPU", accent: .glanceBlue)
        let memory = UsageCardView(title: "内存", accent: .glanceViolet)
        let appUsage = AppUsageCardView()
        let footer = makeFooter()

        network.onSelect = { [weak settings] in settings?.selectDetailMetric(.network) }
        cpu.onSelect = { [weak settings] in settings?.selectDetailMetric(.cpu) }
        memory.onSelect = { [weak settings] in settings?.selectDetailMetric(.memory) }

        networkCard = network
        cpuCard = cpu
        memoryCard = memory
        appUsageCard = appUsage

        let usageRow = NSStackView(views: [cpu, memory])
        usageRow.orientation = .horizontal
        usageRow.spacing = 10
        usageRow.distribution = .fillEqually
        usageRow.translatesAutoresizingMaskIntoConstraints = false

        let separator1 = makeSectionSeparator()
        let separator2 = makeSectionSeparator()

        let stack = NSStackView(views: [network, usageRow, separator1, appUsage, separator2, footer])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 0
        stack.setCustomSpacing(10, after: network)
        stack.setCustomSpacing(10, after: usageRow)
        stack.setCustomSpacing(10, after: separator1)
        stack.setCustomSpacing(8, after: appUsage)
        stack.setCustomSpacing(4, after: separator2)
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),
            network.heightAnchor.constraint(equalToConstant: 100),
            usageRow.heightAnchor.constraint(equalToConstant: 116),
            appUsage.heightAnchor.constraint(equalToConstant: 151),
            footer.heightAnchor.constraint(equalToConstant: 28),
            network.widthAnchor.constraint(equalTo: stack.widthAnchor),
            usageRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            appUsage.widthAnchor.constraint(equalTo: stack.widthAnchor),
            footer.widthAnchor.constraint(equalTo: stack.widthAnchor),
            separator1.widthAnchor.constraint(equalTo: stack.widthAnchor),
            separator2.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])

        install(container, animated: animated)
        refreshDashboard()
        refreshAppUsage()
    }

    private func showSettings(animated: Bool) {
        let settingsView = SettingsPanelView(settings: settings)
        settingsView.onBack = { [weak self] in self?.showDashboard(animated: true) }
        install(settingsView, animated: animated)
    }

    private func makeFooter() -> NSView {
        let container = NSView()
        let settingsButton = makePlainButton(
            title: "监控设置…",
            symbol: "gearshape",
            target: self,
            action: #selector(openSettings)
        )
        settingsButton.toolTip = "设置菜单栏显示内容"
        settingsButton.font = .systemFont(ofSize: 12, weight: .regular)
        settingsButton.alignment = .left
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(settingsButton)

        NSLayoutConstraint.activate([
            settingsButton.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            settingsButton.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            settingsButton.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        return container
    }

    @objc private func openSettings() {
        showSettings(animated: true)
    }

}

// MARK: - Dashboard components

private final class NetworkCardView: SelectableCardView {
    private let upload = NetworkMetricColumn(title: "上传", symbol: "arrow.up", accent: .glanceBlue)
    private let download = NetworkMetricColumn(title: "下载", symbol: "arrow.down", accent: .glanceCyan)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureSelection(accent: .glanceBlue, accessibilityLabel: "网络占用应用")

        let divider = makeSectionSeparator(vertical: true)
        let columns = NSStackView(views: [upload, divider, download])
        columns.orientation = .horizontal
        columns.alignment = .centerY
        columns.distribution = .fill
        columns.spacing = 12
        columns.translatesAutoresizingMaskIntoConstraints = false
        addSubview(columns)

        NSLayoutConstraint.activate([
            columns.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            columns.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            columns.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            columns.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            divider.widthAnchor.constraint(equalToConstant: 1),
            divider.heightAnchor.constraint(equalToConstant: 64),
            upload.widthAnchor.constraint(equalTo: download.widthAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(snapshot: MetricsSnapshot, downloadHistory: [Double], uploadHistory: [Double]) {
        upload.update(value: RateFormatter.detail(snapshot.uploadBytesPerSecond), history: uploadHistory)
        download.update(value: RateFormatter.detail(snapshot.downloadBytesPerSecond), history: downloadHistory)
    }
}

private final class NetworkMetricColumn: NSView {
    private let valueLabel = makeLabel("0 KB/s", size: 20, weight: .semibold, color: .labelColor, monospaced: true)
    private let sparkline: SparklineView

    init(title: String, symbol: String, accent: NSColor) {
        sparkline = SparklineView(accents: [accent])
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let icon = makeSymbol(symbol, size: 10, weight: .semibold, color: accent)
        let titleLabel = makeLabel(title, size: 11, weight: .semibold, color: accent)
        let titleRow = NSStackView(views: [icon, titleLabel, NSView()])
        titleRow.orientation = .horizontal
        titleRow.alignment = .centerY
        titleRow.spacing = 5

        let stack = NSStackView(views: [titleRow, valueLabel, sparkline])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        stack.setCustomSpacing(6, after: valueLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        valueLabel.lineBreakMode = .byClipping
        valueLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            titleRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            sparkline.widthAnchor.constraint(equalTo: stack.widthAnchor),
            sparkline.heightAnchor.constraint(equalToConstant: 28)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(value: String, history: [Double]) {
        valueLabel.stringValue = value
        sparkline.series = [history]
    }
}

private final class UsageCardView: SelectableCardView {
    private let valueLabel = makeLabel("0%", size: 20, weight: .semibold, color: .labelColor, monospaced: true)
    private let captionLabel = makeLabel("", size: 10, weight: .regular, color: .secondaryLabelColor)
    private let sparkline: SparklineView

    init(title: String, accent: NSColor) {
        sparkline = SparklineView(accents: [accent], fixedMaximum: 100)
        super.init(frame: .zero)
        configureSelection(accent: accent, accessibilityLabel: "\(title)占用应用")

        let titleLabel = makeLabel(title, size: 11, weight: .semibold, color: accent)

        let stack = NSStackView(views: [titleLabel, valueLabel, sparkline, captionLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        stack.setCustomSpacing(6, after: valueLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            sparkline.widthAnchor.constraint(equalTo: stack.widthAnchor),
            sparkline.heightAnchor.constraint(equalToConstant: 28)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(value: String, caption: String, history: [Double]) {
        valueLabel.stringValue = value
        captionLabel.stringValue = caption
        sparkline.series = [history]
    }
}

private final class AppUsageCardView: NSView {
    private let titleLabel = makeLabel("网络占用", size: 11, weight: .regular, color: .secondaryLabelColor)
    private let rows = NSStackView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false

        let header = NSStackView(views: [titleLabel, NSView()])
        header.orientation = .horizontal
        header.alignment = .centerY

        rows.orientation = .vertical
        rows.alignment = .leading
        rows.spacing = 0

        let stack = NSStackView(views: [header, rows])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor),
            header.widthAnchor.constraint(equalTo: stack.widthAnchor),
            rows.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])

        update(metric: .network, networkApps: [], processApps: [], ready: false)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(
        metric: DetailMetric,
        networkApps: [NetworkAppMetric],
        processApps: [ProcessAppMetric],
        ready: Bool
    ) {
        for view in rows.arrangedSubviews {
            rows.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        let hasApps = metric == .network ? !networkApps.isEmpty : !processApps.isEmpty
        let emptyMessage: String
        let loadingMessage: String
        let emptySymbol: String

        switch metric {
        case .network:
            titleLabel.stringValue = "网络占用"
            emptyMessage = "当前没有明显联网应用"
            loadingMessage = "正在读取应用网速…"
            emptySymbol = "network.slash"
        case .cpu:
            titleLabel.stringValue = "CPU 占用"
            emptyMessage = "当前没有可显示的进程"
            loadingMessage = "正在读取 CPU 占用…"
            emptySymbol = "cpu"
        case .memory:
            titleLabel.stringValue = "内存占用"
            emptyMessage = "当前没有可显示的进程"
            loadingMessage = "正在读取内存占用…"
            emptySymbol = "memorychip"
        }

        guard hasApps else {
            let message = ready ? emptyMessage : loadingMessage
            let label = makeLabel(message, size: 11, weight: .medium, color: .secondaryLabelColor)
            let row: NSStackView
            if ready {
                let icon = makeSymbol(emptySymbol, size: 12, weight: .medium, color: .tertiaryLabelColor)
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
            row.heightAnchor.constraint(equalToConstant: 123).isActive = true
            rows.addArrangedSubview(row)
            return
        }

        if metric == .network {
            for app in networkApps.prefix(4) {
                addRow(
                    AppUsageRowView(
                        name: app.name,
                        iconPath: app.iconPath,
                        primaryText: "↑ \(RateFormatter.menu(app.uploadBytesPerSecond))/s",
                        primaryColor: .secondaryLabelColor,
                        secondaryText: "↓ \(RateFormatter.menu(app.downloadBytesPerSecond))/s",
                        secondaryColor: .labelColor
                    )
                )
            }
            return
        }

        for app in processApps.prefix(4) {
            let value: String
            if metric == .cpu {
                value = CPUFormatter.process(app.cpuPercent)
            } else {
                value = MemoryFormatter.process(app.memoryBytes)
            }
            addRow(
                AppUsageRowView(
                    name: app.name,
                    iconPath: app.iconPath,
                    primaryText: value,
                    primaryColor: .labelColor
                )
            )
        }
    }

    private func addRow(_ row: AppUsageRowView) {
        if !rows.arrangedSubviews.isEmpty {
            let divider = makeSectionSeparator(inset: 34)
            rows.addArrangedSubview(divider)
            divider.widthAnchor.constraint(equalTo: rows.widthAnchor).isActive = true
        }
        rows.addArrangedSubview(row)
        row.heightAnchor.constraint(equalToConstant: 30).isActive = true
        row.widthAnchor.constraint(equalTo: rows.widthAnchor).isActive = true
    }
}

private final class AppUsageRowView: NSView {
    init(
        name appName: String,
        iconPath: String?,
        primaryText: String,
        primaryColor: NSColor,
        secondaryText: String? = nil,
        secondaryColor: NSColor = .secondaryLabelColor
    ) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let appIcon = AppIconView(iconPath: iconPath, appName: appName)
        let name = makeLabel(appName, size: 12, weight: .medium, color: .labelColor)
        name.lineBreakMode = .byTruncatingTail

        let primary = makeLabel(primaryText, size: 11, weight: .semibold, color: primaryColor, monospaced: true)
        primary.alignment = .right
        primary.setContentHuggingPriority(.required, for: .horizontal)
        primary.setContentCompressionResistancePriority(.required, for: .horizontal)

        let values = NSStackView(views: [primary])
        values.orientation = .horizontal
        values.alignment = .centerY
        values.spacing = 12
        if let secondaryText {
            let secondary = makeLabel(secondaryText, size: 11, weight: .semibold, color: secondaryColor, monospaced: true)
            secondary.alignment = .right
            secondary.setContentHuggingPriority(.required, for: .horizontal)
            secondary.setContentCompressionResistancePriority(.required, for: .horizontal)
            values.addArrangedSubview(secondary)
        }

        name.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        name.setContentHuggingPriority(.defaultLow, for: .horizontal)
        appIcon.translatesAutoresizingMaskIntoConstraints = false
        values.translatesAutoresizingMaskIntoConstraints = false

        let row = NSStackView(views: [appIcon, name, NSView(), values])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 9
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)

        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            row.centerYAnchor.constraint(equalTo: centerYAnchor),
            appIcon.widthAnchor.constraint(equalToConstant: 25),
            appIcon.heightAnchor.constraint(equalToConstant: 25)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - Settings

private final class SettingsPanelView: NSView {
    var onBack: (() -> Void)?
    private let settings: SettingsStore
    private let updateChecker = UpdateChecker()
    private let launchError = makeLabel("", size: 10, weight: .medium, color: .glanceOrange)
    private let updateRow = UpdateRow()
    private var availableReleaseURL: URL?

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
        let title = makeLabel("监控设置", size: 15, weight: .semibold, color: .labelColor)
        let header = NSStackView(views: [back, title, NSView()])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 8

        let launchRow = ToggleRow(
            title: "开机自动启动",
            subtitle: "登录后自动出现在菜单栏",
            symbol: "power",
            isOn: settings.launchAtLogin,
            onChange: { [weak self] enabled in
                self?.settings.setLaunchAtLogin(enabled)
                self?.launchError.stringValue = self?.settings.launchError ?? ""
                self?.launchError.isHidden = self?.launchError.stringValue.isEmpty ?? true
            }
        )
        launchError.lineBreakMode = .byWordWrapping
        launchError.maximumNumberOfLines = 2
        launchError.isHidden = launchError.stringValue.isEmpty

        updateRow.onAction = { [weak self] in self?.handleUpdateAction() }

        let privacyTitle = makeLabel("关于数据", size: 12, weight: .semibold, color: .labelColor)
        let privacyIcon = makeSymbol("lock.shield", size: 12, weight: .semibold, color: .glanceBlue)
        let privacyHeader = NSStackView(views: [privacyIcon, privacyTitle, NSView()])
        privacyHeader.orientation = .horizontal
        privacyHeader.spacing = 7
        let privacyText = makeLabel(
            "运行数据始终只在本机处理。只有你主动点击“检查更新”时，NetHalo 才会访问 GitHub，不上传设备或使用数据。",
            size: 11,
            weight: .regular,
            color: .secondaryLabelColor
        )
        privacyText.lineBreakMode = .byWordWrapping
        privacyText.maximumNumberOfLines = 0
        privacyText.preferredMaxLayoutWidth = 270
        privacyText.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let privacyStack = NSStackView(views: [privacyHeader, privacyText])
        privacyStack.orientation = .vertical
        privacyStack.alignment = .leading
        privacyStack.spacing = 8

        let about = makeLabel(
            "NetHalo \(currentVersion) · 原生 macOS",
            size: 10,
            weight: .medium,
            color: .tertiaryLabelColor
        )
        about.alignment = .center

        let headerDivider = makeSectionSeparator()
        let launchDivider = makeSectionSeparator(inset: 34)
        let updateDivider = makeSectionSeparator()
        let stack = NSStackView(views: [
            header,
            headerDivider,
            launchRow,
            launchError,
            launchDivider,
            updateRow,
            updateDivider,
            privacyStack,
            NSView(),
            about
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 0
        stack.setCustomSpacing(8, after: launchError)
        stack.setCustomSpacing(12, after: updateDivider)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            header.heightAnchor.constraint(equalToConstant: 48),
            header.widthAnchor.constraint(equalTo: stack.widthAnchor),
            launchRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            launchError.widthAnchor.constraint(equalTo: stack.widthAnchor),
            updateRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            privacyStack.widthAnchor.constraint(equalTo: stack.widthAnchor),
            about.widthAnchor.constraint(equalTo: stack.widthAnchor),
            headerDivider.widthAnchor.constraint(equalTo: stack.widthAnchor),
            launchDivider.widthAnchor.constraint(equalTo: stack.widthAnchor),
            updateDivider.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }

    @objc private func goBack() {
        onBack?()
    }

    private var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.3"
    }

    private func handleUpdateAction() {
        if let availableReleaseURL {
            NSWorkspace.shared.open(availableReleaseURL)
            return
        }

        updateRow.showChecking()
        updateChecker.check(currentVersion: currentVersion) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .current(let latestVersion):
                    self.updateRow.showCurrent(version: latestVersion)
                case .updateAvailable(let version, let releaseURL):
                    self.availableReleaseURL = releaseURL
                    self.updateRow.showAvailable(version: version)
                case .failed(let message):
                    self.updateRow.showFailure(message)
                }
            }
        }
    }
}

private final class UpdateRow: NSView {
    var onAction: (() -> Void)?

    private let subtitleLabel = makeLabel(
        "仅在你点击时访问 GitHub",
        size: 10,
        weight: .regular,
        color: .secondaryLabelColor
    )
    private lazy var actionButton: NSButton = {
        let button = NSButton(title: "检查", target: self, action: #selector(performAction))
        button.controlSize = .small
        button.bezelStyle = .rounded
        button.font = .systemFont(ofSize: 10, weight: .semibold)
        return button
    }()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false

        let icon = makeSymbol("arrow.triangle.2.circlepath", size: 13, weight: .semibold, color: .glanceBlue)
        let titleLabel = makeLabel("检查更新", size: 12, weight: .semibold, color: .labelColor)
        let labels = NSStackView(views: [titleLabel, subtitleLabel])
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 2

        let stack = NSStackView(views: [icon, labels, NSView(), actionButton])
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

    func showChecking() {
        subtitleLabel.stringValue = "正在获取最新版本…"
        subtitleLabel.textColor = .secondaryLabelColor
        actionButton.title = "检查中"
        actionButton.isEnabled = false
    }

    func showCurrent(version: String) {
        subtitleLabel.stringValue = "已是最新版本（\(displayVersion(version))）"
        subtitleLabel.textColor = .glanceGreen
        actionButton.title = "再检查"
        actionButton.isEnabled = true
    }

    func showAvailable(version: String) {
        subtitleLabel.stringValue = "发现新版本 \(displayVersion(version))"
        subtitleLabel.textColor = .glanceBlue
        actionButton.title = "查看"
        actionButton.isEnabled = true
    }

    func showFailure(_ message: String) {
        subtitleLabel.stringValue = message
        subtitleLabel.textColor = .glanceOrange
        actionButton.title = "重试"
        actionButton.isEnabled = true
    }

    @objc private func performAction() {
        onAction?()
    }

    private func displayVersion(_ version: String) -> String {
        version.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
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

private final class PanelRootView: NSView {
    private let interactiveFrame: NSRect

    init(frame frameRect: NSRect, interactiveFrame: NSRect) {
        self.interactiveFrame = interactiveFrame
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isOpaque: Bool { false }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard interactiveFrame.contains(point) else { return nil }
        return super.hitTest(point)
    }
}

private final class RoundedPanelShadowView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 20
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = false
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.18
        layer?.shadowRadius = 15
        layer?.shadowOffset = CGSize(width: 0, height: -4)
        updateShadowPath()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isOpaque: Bool { false }

    override func layout() {
        super.layout()
        updateShadowPath()
    }

    private func updateShadowPath() {
        layer?.shadowPath = CGPath(
            roundedRect: bounds,
            cornerWidth: 20,
            cornerHeight: 20,
            transform: nil
        )
    }
}

private final class RoundedPanelRimView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isOpaque: Bool { false }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(roundedRect: rect, xRadius: 19.5, yRadius: 19.5)
        NSColor.separatorColor.withAlphaComponent(0.20).setStroke()
        path.lineWidth = 0.5
        path.stroke()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}

private class SelectableCardView: NSView {
    var onSelect: (() -> Void)?

    private var selectionAccent = NSColor.glanceBlue
    private var metricSelected = false
    private var hovered = false
    private var trackingArea: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        let recognizer = NSClickGestureRecognizer(target: self, action: #selector(activateSelection))
        addGestureRecognizer(recognizer)
        focusRingType = .none
        setAccessibilityRole(.button)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var acceptsFirstResponder: Bool { true }

    func configureSelection(accent: NSColor, accessibilityLabel: String) {
        selectionAccent = accent
        setAccessibilityLabel(accessibilityLabel)
    }

    func setMetricSelected(_ selected: Bool) {
        guard metricSelected != selected else { return }
        metricSelected = selected
        setAccessibilityValue(selected ? "已选中" : "未选中")
        needsDisplay = true
    }

    @objc private func activateSelection() {
        onSelect?()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 || event.keyCode == 49 {
            activateSelection()
        } else {
            super.keyDown(with: event)
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseEnteredAndExited],
            owner: self
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        hovered = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        hovered = false
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(roundedRect: rect, xRadius: 12, yRadius: 12)
        let dark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

        let base = dark
            ? NSColor.black.withAlphaComponent(0.08)
            : NSColor.white.withAlphaComponent(0.14)
        base.setFill()
        path.fill()

        if metricSelected {
            selectionAccent.withAlphaComponent(0.08).setFill()
            path.fill()
        } else if hovered {
            NSColor.labelColor.withAlphaComponent(0.04).setFill()
            path.fill()
        }

        if metricSelected {
            selectionAccent.withAlphaComponent(0.5).setStroke()
            path.lineWidth = 1
        } else {
            let border = dark
                ? NSColor.white.withAlphaComponent(0.10)
                : NSColor.separatorColor.withAlphaComponent(0.22)
            border.setStroke()
            path.lineWidth = 0.7
        }
        path.stroke()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}

private final class SparklineView: NSView {
    var series: [[Double]] = [] { didSet { needsDisplay = true } }
    private let accents: [NSColor]
    private let fixedMaximum: Double?

    init(accents: [NSColor], fixedMaximum: Double? = nil) {
        self.accents = accents
        self.fixedMaximum = fixedMaximum
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let drawable = series.filter { $0.count > 1 }
        guard !drawable.isEmpty, bounds.width > 0, bounds.height > 0 else {
            let baseline = NSBezierPath()
            baseline.move(to: NSPoint(x: 0, y: 1))
            baseline.line(to: NSPoint(x: bounds.maxX, y: 1))
            (accents.first ?? NSColor.secondaryLabelColor).withAlphaComponent(0.18).setStroke()
            baseline.lineWidth = 1
            baseline.stroke()
            return
        }

        let maximum = max(1, fixedMaximum ?? drawable.flatMap { $0 }.max() ?? 1)
        for (index, values) in drawable.enumerated() {
            let accent = accents[min(index, accents.count - 1)]
            let xStep = bounds.width / CGFloat(values.count - 1)
            let line = NSBezierPath()
            line.lineWidth = 2
            line.lineCapStyle = .round
            line.lineJoinStyle = .round

            for (pointIndex, value) in values.enumerated() {
                let ratio = min(1, max(0, value / maximum))
                let point = NSPoint(
                    x: CGFloat(pointIndex) * xStep,
                    y: 1 + CGFloat(ratio) * (bounds.height - 2)
                )
                pointIndex == 0 ? line.move(to: point) : line.line(to: point)
            }

            if let fill = line.copy() as? NSBezierPath {
                fill.line(to: NSPoint(x: CGFloat(values.count - 1) * xStep, y: 1))
                fill.line(to: NSPoint(x: 0, y: 1))
                fill.close()
                accent.withAlphaComponent(0.12).setFill()
                fill.fill()
            }
            accent.setStroke()
            line.stroke()
        }
    }
}

private final class AppIconView: NSView {
    init(iconPath: String?, appName: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let image: NSImage
        if let iconPath {
            image = NSWorkspace.shared.icon(forFile: iconPath)
        } else {
            image = NSImage(systemSymbolName: "terminal.fill", accessibilityDescription: nil) ?? NSImage()
            wantsLayer = true
            layer?.cornerRadius = 7
            layer?.backgroundColor = NSColor.glanceBlue.withAlphaComponent(0.10).cgColor
        }

        let imageView = NSImageView(image: image)
        imageView.imageScaling = .scaleProportionallyDown
        imageView.setAccessibilityElement(true)
        imageView.setAccessibilityLabel("\(appName) 图标")
        addSubview(imageView)
        imageView.pinToEdges(of: self)
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

private func makeSectionSeparator(vertical: Bool = false, inset: CGFloat = 0) -> NSView {
    let container = NSView()
    container.translatesAutoresizingMaskIntoConstraints = false

    let box = NSBox()
    box.boxType = .separator
    box.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(box)

    if vertical {
        NSLayoutConstraint.activate([
            box.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            box.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            box.topAnchor.constraint(equalTo: container.topAnchor),
            box.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
    } else {
        container.heightAnchor.constraint(equalToConstant: 1).isActive = true
        NSLayoutConstraint.activate([
            box.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: inset),
            box.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            box.topAnchor.constraint(equalTo: container.topAnchor),
            box.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
    }

    return container
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
