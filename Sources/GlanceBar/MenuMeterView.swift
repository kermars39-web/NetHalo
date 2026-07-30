import AppKit

@MainActor
final class MenuMeterView: NSView {
    private var download = "0K"
    private var upload = "0K"

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        // Let the underlying NSStatusBarButton receive every click.
        nil
    }

    func update(download: String, upload: String) {
        guard self.download != download || self.upload != upload else { return }
        self.download = download
        self.upload = upload
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        drawRow(
            arrow: "↑",
            value: upload,
            y: bounds.midY + 0.2,
            color: .systemBlue
        )
        drawRow(
            arrow: "↓",
            value: download,
            y: max(0, bounds.midY - 10.5),
            color: .systemTeal
        )
    }

    private func drawRow(arrow: String, value: String, y: CGFloat, color: NSColor) {
        let arrowFont = NSFont.systemFont(ofSize: 8.5, weight: .bold)
        let valueFont = NSFont.monospacedDigitSystemFont(ofSize: 8.5, weight: .medium)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .left
        paragraph.lineBreakMode = .byClipping

        let arrowRect = NSRect(x: 1, y: y, width: 10, height: 11)
        let valueRect = NSRect(x: 11, y: y, width: max(0, bounds.width - 12), height: 11)

        (arrow as NSString).draw(
            in: arrowRect,
            withAttributes: [
                .font: arrowFont,
                .foregroundColor: color
            ]
        )
        (value as NSString).draw(
            in: valueRect,
            withAttributes: [
                .font: valueFont,
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: paragraph
            ]
        )
    }
}
