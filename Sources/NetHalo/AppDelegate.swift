import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let model = MetricsStore()
    private let settings = SettingsStore()
    private let panel = StatusPanel()
    private var statusItem: NSStatusItem?
    private var displayedRates: (download: String, upload: String)?
    private var cancellables = Set<AnyCancellable>()
    private var localEventMonitor: Any?
    private var globalMouseMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        configurePanel()
        configureEventMonitors()
        connectUpdates()
        model.start()

        if CommandLine.arguments.contains("--show-panel") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                NSApp.activate(ignoringOtherApps: true)
                self?.openPopover()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.stop()
        if let localEventMonitor { NSEvent.removeMonitor(localEventMonitor) }
        if let globalMouseMonitor { NSEvent.removeMonitor(globalMouseMonitor) }
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: 44)
        guard let button = item.button else { return }

        button.title = ""
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleNone
        if let cell = button.cell as? NSButtonCell {
            cell.showsStateBy = cell.highlightsBy
        }
        button.target = self
        button.action = #selector(handleStatusItemClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.toolTip = "NetHalo"
        button.setAccessibilityLabel("NetHalo 实时网速")

        statusItem = item
        updateStatusMeter(model.snapshot)
    }

    private func configurePanel() {
        panel.delegate = self
        panel.setContentSize(DashboardViewController.windowSize)
        panel.contentViewController = DashboardViewController(
            model: model,
            settings: settings,
            onQuit: { NSApp.terminate(nil) }
        )
    }

    private func configureEventMonitors() {
        localEventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown]
        ) { [weak self] event in
            guard let self, self.panel.isVisible else { return event }

            if event.keyCode == 53 {
                self.closePanel()
                return nil
            }
            return event
        }

        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                self?.closePanelAfterOutsideClick()
            }
        }
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
        if displayedRates?.download != download || displayedRates?.upload != upload {
            button.image = MenuMeterView.image(download: download, upload: upload)
            displayedRates = (download, upload)
        }
        button.toolTip = "下载 \(download)/s · 上传 \(upload)/s"
        button.setAccessibilityValue("下载 \(download) 每秒，上传 \(upload) 每秒")
    }

    @objc
    private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        // Native tracking can reset the cell after sending its action.
        // Reconcile the persistent selection once tracking has finished.
        defer {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.statusItem?.button?.state = self.panel.isVisible ? .on : .off
            }
        }
        if NSApp.currentEvent?.type == .rightMouseUp {
            closePanel()
            showContextMenu(from: sender)
        } else {
            togglePanel(from: sender)
        }
    }

    private func togglePanel(from button: NSStatusBarButton) {
        if panel.isVisible {
            closePanel()
            return
        }

        model.setDetailsVisible(true)
        positionPanel(below: button)
        panel.makeKeyAndOrderFront(nil)
        button.state = .on
    }

    private func positionPanel(below button: NSStatusBarButton) {
        guard let buttonWindow = button.window else { return }
        let buttonFrame = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let screenFrame = (buttonWindow.screen ?? NSScreen.main)?.visibleFrame ?? .zero
        let size = panel.frame.size
        let horizontalInset: CGFloat = 8

        var x = buttonFrame.midX - size.width / 2
        x = max(screenFrame.minX + horizontalInset, min(x, screenFrame.maxX - size.width - horizontalInset))
        let y = screenFrame.maxY - size.height
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func closePanel() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
        statusItem?.button?.state = .off
        model.setDetailsVisible(false)
    }

    private func closePanelAfterOutsideClick() {
        guard panel.isVisible else { return }
        let mouseLocation = NSEvent.mouseLocation
        if panel.frame.contains(mouseLocation) { return }

        if let button = statusItem?.button,
           let buttonWindow = button.window {
            let buttonFrame = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
            if buttonFrame.contains(mouseLocation) { return }
        }

        closePanel()
    }

    private func showContextMenu(from button: NSStatusBarButton) {
        let menu = NSMenu()

        let openItem = NSMenuItem(title: "打开 NetHalo", action: #selector(openPopover), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "退出 NetHalo", action: #selector(quitApplication), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
        button.performClick(nil)
        statusItem?.menu = nil
    }

    @objc
    private func openPopover() {
        guard let button = statusItem?.button else { return }
        togglePanel(from: button)
    }

    @objc
    private func quitApplication() {
        NSApp.terminate(nil)
    }

}

private final class StatusPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(origin: .zero, size: DashboardViewController.windowSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = .popUpMenu
        isFloatingPanel = true
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
