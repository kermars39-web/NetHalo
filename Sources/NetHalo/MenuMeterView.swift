import AppKit

@MainActor
final class MenuMeterView: NSView {
    private static let verticalOpticalOffset: CGFloat = -1

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
            y: bounds.midY + 0.2 + Self.verticalOpticalOffset
        )
        drawRow(
            arrow: "↓",
            value: download,
            y: max(0, bounds.midY - 10.5 + Self.verticalOpticalOffset)
        )
    }

    private func drawRow(arrow: String, value: String, y: CGFloat) {
        let arrowFont = NSFont.systemFont(ofSize: 8.5, weight: .bold)
        let valueFont = NSFont.monospacedDigitSystemFont(ofSize: 8.5, weight: .medium)
        let unitFont = NSFont.systemFont(ofSize: 7.5, weight: .medium)
        let arrowAttributes: [NSAttributedString.Key: Any] = [
            .font: arrowFont,
            .foregroundColor: NSColor.labelColor
        ]
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .right
        paragraph.lineBreakMode = .byClipping
        let displayString = "\(value)/s"
        let displayValue = NSMutableAttributedString(
            string: displayString,
            attributes: [
                .font: valueFont,
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: paragraph
            ]
        )
        displayValue.addAttribute(
            .font,
            value: unitFont,
            range: NSRange(location: (displayString as NSString).length - 2, length: 2)
        )

        let arrowColumnWidth: CGFloat = 8
        let arrowRect = NSRect(x: 0, y: y, width: arrowColumnWidth, height: 11)
        let valueRect = NSRect(
            x: arrowRect.maxX,
            y: y,
            width: max(0, bounds.width - arrowRect.maxX - 1),
            height: 11
        )

        (arrow as NSString).draw(in: arrowRect, withAttributes: arrowAttributes)
        displayValue.draw(
            with: valueRect,
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine]
        )
    }
}
