import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let model = MetricsStore()
    private let settings = SettingsStore()
    private let popover = NSPopover()
    private var statusItem: NSStatusItem?
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
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = item.button else { return }

        let icon = NSImage(
            systemSymbolName: "waveform.path.ecg",
            accessibilityDescription: "GlanceBar 系统状态"
        )
        icon?.isTemplate = true
        button.image = icon
        button.imagePosition = .imageLeading
        button.target = self
        button.action = #selector(handleStatusItemClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.toolTip = "GlanceBar"

        statusItem = item
        updateStatusTitle(model.snapshot)
    }

    private func configurePopover() {
        popover.contentSize = NSSize(width: 390, height: 590)
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
                self?.updateStatusTitle(snapshot)
            }
            .store(in: &cancellables)

        settings.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.updateStatusTitle(self.model.snapshot)
                }
            }
            .store(in: &cancellables)
    }

    private func updateStatusTitle(_ snapshot: MetricsSnapshot) {
        guard let button = statusItem?.button else { return }
        var components: [String] = []

        if settings.showNetwork {
            components.append(
                "↓\(RateFormatter.menu(snapshot.downloadBytesPerSecond))  ↑\(RateFormatter.menu(snapshot.uploadBytesPerSecond))"
            )
        }
        if settings.showCPU {
            components.append("CPU \(Int(snapshot.cpuPercent.rounded()))%")
        }
        if settings.showMemory {
            components.append("MEM \(Int(snapshot.memoryPercent.rounded()))%")
        }
        if components.isEmpty {
            components.append("Glance")
        }

        button.attributedTitle = NSAttributedString(
            string: "  " + components.joined(separator: "   "),
            attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium),
                .foregroundColor: NSColor.labelColor
            ]
        )

        let symbolName = snapshot.health == .busy
            ? "exclamationmark.triangle.fill"
            : "waveform.path.ecg"
        let icon = NSImage(systemSymbolName: symbolName, accessibilityDescription: snapshot.health.title)
        icon?.isTemplate = true
        button.image = icon
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
