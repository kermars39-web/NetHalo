import AppKit
import Darwin

/// Offscreen panel preview for design iteration: `NetHalo --render-preview`
/// writes /tmp/nethalo-preview-light.png and /tmp/nethalo-preview-dark.png.
enum PreviewRenderer {
    static func run() -> Int32 {
        MainActor.assumeIsolated {
            let application = NSApplication.shared
            application.setActivationPolicy(.accessory)
            application.appearance = NSAppearance(named: .aqua)

            let model = MetricsStore()
            let settings = SettingsStore()
            let controller = DashboardViewController(model: model, settings: settings, onQuit: {})
            let view = controller.view
            view.frame = NSRect(origin: .zero, size: DashboardViewController.windowSize)

            model.start()
            model.setDetailsVisible(true)
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 6))

            render(view, appearance: NSAppearance(named: .aqua), to: "/tmp/nethalo-preview-light.png")
            render(view, appearance: NSAppearance(named: .darkAqua), to: "/tmp/nethalo-preview-dark.png")
        }
        return 0
    }

    @MainActor
    private static func render(_ view: NSView, appearance: NSAppearance?, to path: String) {
        view.appearance = appearance
        view.layoutSubtreeIfNeeded()
        view.display()

        let bounds = view.bounds
        guard let content = view.bitmapImageRepForCachingDisplay(in: bounds) else { return }
        view.cacheDisplay(in: bounds, to: content)

        guard
            let canvas = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: Int(bounds.width),
                pixelsHigh: Int(bounds.height),
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            )
        else { return }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: canvas)
        NSColor(calibratedWhite: 0.93, alpha: 1).setFill()
        bounds.fill()
        content.draw(in: bounds)
        NSGraphicsContext.restoreGraphicsState()

        if let png = canvas.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: path))
        }
    }
}
