import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let model = MetricsStore()
    private let settings = SettingsStore()
    private let popover = NSPopover()
    private var statusItem: NSStatusItem?
    private weak var menuMeterView: MenuMeterView?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        configurePopover()
        connectUpdates()
        model.start()

        if CommandLine.arguments.contains("--show-panel") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.openPopover()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.stop()
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: 44)
        guard let button = item.button else { return }

        button.image = nil
        button.title = ""
        button.target = self
        button.action = #selector(handleStatusItemClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.toolTip = "GlanceBar"
        button.setAccessibilityLabel("GlanceBar 实时网速")

        let meter = MenuMeterView()
        button.addSubview(meter)
        NSLayoutConstraint.activate([
            meter.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            meter.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            meter.topAnchor.constraint(equalTo: button.topAnchor),
            meter.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])
        menuMeterView = meter

        statusItem = item
        updateStatusMeter(model.snapshot)
    }

    private func configurePopover() {
        popover.contentSize = NSSize(width: 342, height: 550)
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentViewController = DashboardViewController(
            model: model,
            settings: settings,
            onQuit: { NSApp.terminate(nil) }
        )
    }

    private func connectUpdates() {
        model.$snapshot
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                self?.updateStatusMeter(snapshot)
            }
            .store(in: &cancellables)
    }

    private func updateStatusMeter(_ snapshot: MetricsSnapshot) {
        guard let button = statusItem?.button else { return }
        let download = RateFormatter.menu(snapshot.downloadBytesPerSecond)
        let upload = RateFormatter.menu(snapshot.uploadBytesPerSecond)
        menuMeterView?.update(download: download, upload: upload)
        button.toolTip = "下载 \(download)/s · 上传 \(upload)/s"
        button.setAccessibilityValue("下载 \(download) 每秒，上传 \(upload) 每秒")
    }

    @objc
    private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu(from: sender)
        } else {
            togglePopover(from: sender)
        }
    }

    private func togglePopover(from button: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(nil)
            return
        }

        model.setDetailsVisible(true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func showContextMenu(from button: NSStatusBarButton) {
        let menu = NSMenu()

        let openItem = NSMenuItem(title: "打开 GlanceBar", action: #selector(openPopover), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "退出 GlanceBar", action: #selector(quitApplication), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
        button.performClick(nil)
        statusItem?.menu = nil
    }

    @objc
    private func openPopover() {
        guard let button = statusItem?.button else { return }
        togglePopover(from: button)
    }

    @objc
    private func quitApplication() {
        NSApp.terminate(nil)
    }

    func popoverDidClose(_ notification: Notification) {
        model.setDetailsVisible(false)
    }
}
