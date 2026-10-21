import AppKit

enum MenuMeterView {
    static let imageSize = NSSize(width: 40, height: 22)

    static func image(download: String, upload: String) -> NSImage {
        // The native status button tints this alpha mask for the menu bar's
        // backdrop and highlighted state, independently of the panel appearance.
        let image = NSImage(size: imageSize, flipped: false) { bounds in
            drawRow(arrow: "↑", value: upload, y: 10.2, width: bounds.width)
            drawRow(arrow: "↓", value: download, y: 0, width: bounds.width)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "上传 \(upload)/s，下载 \(download)/s"
        return image
    }

    private static func drawRow(arrow: String, value: String, y: CGFloat, width: CGFloat) {
        let arrowFont = NSFont.systemFont(ofSize: 8.5, weight: .bold)
        let valueFont = NSFont.monospacedDigitSystemFont(ofSize: 8.5, weight: .medium)
        let unitFont = NSFont.systemFont(ofSize: 7.5, weight: .medium)
        let arrowAttributes: [NSAttributedString.Key: Any] = [
            .font: arrowFont,
            .foregroundColor: NSColor.black
        ]
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .right
        paragraph.lineBreakMode = .byClipping
        let displayString = "\(value)/s"
        let displayValue = NSMutableAttributedString(
            string: displayString,
            attributes: [
                .font: valueFont,
                .foregroundColor: NSColor.black,
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
            width: max(0, width - arrowRect.maxX - 1),
            height: 11
        )

        (arrow as NSString).draw(in: arrowRect, withAttributes: arrowAttributes)
        displayValue.draw(
            with: valueRect,
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine]
        )
    }
}
