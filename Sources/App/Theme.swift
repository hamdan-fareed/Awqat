import AppKit

enum Theme {
    static let background = NSColor.black
    static let surface = NSColor(srgbRed: 0.035, green: 0.035, blue: 0.035, alpha: 1)
    static let surfaceRaised = NSColor(srgbRed: 0.060, green: 0.060, blue: 0.060, alpha: 1)
    static let accent = NSColor(srgbRed: 15.0 / 255.0, green: 40.0 / 255.0, blue: 47.0 / 255.0, alpha: 1)
    static let primary = NSColor.white
    static let secondary = NSColor(srgbRed: 0.62, green: 0.62, blue: 0.62, alpha: 1)
    static let tertiary = NSColor(srgbRed: 0.42, green: 0.42, blue: 0.42, alpha: 1)
    static let hairline = NSColor.white.withAlphaComponent(0.10)
    static let hoverFill = NSColor.white.withAlphaComponent(0.055)
    static let borderStrong = NSColor.white.withAlphaComponent(0.24)

    static func font(_ size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        NSFont.systemFont(ofSize: size, weight: weight)
    }

    static func mono(_ size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        NSFont.monospacedDigitSystemFont(ofSize: size, weight: weight)
    }

    static let appName = "Awqat"
}

func makeHairline() -> NSView {
    let view = NSView()
    view.translatesAutoresizingMaskIntoConstraints = false
    view.wantsLayer = true
    view.layer?.backgroundColor = Theme.hairline.cgColor
    view.heightAnchor.constraint(equalToConstant: 1).isActive = true
    return view
}

final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

func label(
    _ text: String,
    font: NSFont = Theme.font(13),
    color: NSColor = Theme.primary
) -> NSTextField {
    let field = NSTextField(labelWithString: text)
    field.font = font
    field.textColor = color
    field.isEditable = false
    field.isBordered = false
    field.drawsBackground = false
    field.isSelectable = false
    field.lineBreakMode = .byWordWrapping
    field.maximumNumberOfLines = 0
    field.translatesAutoresizingMaskIntoConstraints = false
    return field
}
