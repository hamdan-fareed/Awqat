import AppKit

final class FlatButton: NSButton {
    enum Style {
        case accent
        case outline
        case ghost
    }

    var style: Style {
        didSet { updateAppearance() }
    }

    var onClick: (() -> Void)?
    private var isHovering = false
    private var trackingArea: NSTrackingArea?
    private let titleFont: NSFont

    init(
        title: String,
        style: Style,
        font: NSFont = Theme.font(12.5, weight: .medium),
        height: CGFloat = 30,
        onClick: (() -> Void)? = nil
    ) {
        self.style = style
        self.titleFont = font
        self.onClick = onClick
        super.init(frame: .zero)
        self.title = title
        self.isBordered = false
        self.focusRingType = .none
        self.wantsLayer = true
        self.layer?.cornerRadius = 5
        self.translatesAutoresizingMaskIntoConstraints = false
        self.heightAnchor.constraint(equalToConstant: height).isActive = true
        self.target = self
        self.action = #selector(clicked)
        updateAppearance()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isEnabled: Bool {
        didSet { updateAppearance() }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        updateAppearance()
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        updateAppearance()
    }

    override var intrinsicContentSize: NSSize {
        let measured = (title as NSString).size(withAttributes: [.font: titleFont])
        return NSSize(width: ceil(measured.width) + 24, height: 30)
    }

    @objc private func clicked() {
        guard isEnabled else { return }
        onClick?()
    }

    private func updateAppearance() {
        guard let layer else { return }
        let enabled = isEnabled
        let titleColor = enabled ? Theme.primary : Theme.tertiary

        switch style {
        case .accent:
            layer.backgroundColor = (enabled ? Theme.accent : Theme.surfaceRaised).cgColor
            layer.borderWidth = 1
            layer.borderColor = (isHovering && enabled ? Theme.borderStrong : Theme.accent).cgColor
        case .outline:
            layer.backgroundColor = (isHovering && enabled ? Theme.hoverFill : NSColor.clear).cgColor
            layer.borderWidth = 1
            layer.borderColor = (isHovering && enabled ? Theme.borderStrong : Theme.hairline).cgColor
        case .ghost:
            layer.backgroundColor = (isHovering && enabled ? Theme.hoverFill : NSColor.clear).cgColor
            layer.borderWidth = 0
        }

        attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: titleFont,
                .foregroundColor: titleColor
            ]
        )
    }
}

final class FlatPopupButton: NSButton {
    private(set) var items: [String] = []
    var selectedIndex: Int = 0 {
        didSet {
            guard selectedIndex >= 0, selectedIndex < items.count else { return }
            updateTitle()
        }
    }
    var onSelect: ((Int) -> Void)?
    private var isHovering = false
    private var trackingArea: NSTrackingArea?

    init(items: [String], selectedIndex: Int = 0, onSelect: ((Int) -> Void)? = nil) {
        self.items = items
        self.selectedIndex = selectedIndex
        self.onSelect = onSelect
        super.init(frame: .zero)
        self.isBordered = false
        self.focusRingType = .none
        self.wantsLayer = true
        self.layer?.cornerRadius = 5
        self.layer?.borderWidth = 1
        self.translatesAutoresizingMaskIntoConstraints = false
        self.heightAnchor.constraint(equalToConstant: 30).isActive = true
        self.target = self
        self.action = #selector(showMenu)
        updateTitle()
        updateAppearance()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        updateAppearance()
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        updateAppearance()
    }

    func setItems(_ items: [String], selectedIndex: Int) {
        self.items = items
        self.selectedIndex = max(0, min(selectedIndex, max(0, items.count - 1)))
        updateTitle()
    }

    func setSelectedIndex(_ index: Int) {
        guard index >= 0, index < items.count else { return }
        selectedIndex = index
    }

    @objc private func showMenu() {
        guard !items.isEmpty else { return }
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.font = Theme.font(12.5)

        for (index, title) in items.enumerated() {
            let item = NSMenuItem(title: title, action: #selector(selectItem(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = index
            item.state = index == selectedIndex ? .on : .off
            menu.addItem(item)
        }

        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: bounds.height + 4), in: self)
    }

    @objc private func selectItem(_ sender: NSMenuItem) {
        guard let index = sender.representedObject as? Int else { return }
        selectedIndex = index
        onSelect?(index)
    }

    private func updateTitle() {
        guard selectedIndex >= 0, selectedIndex < items.count else {
            attributedTitle = NSAttributedString(string: "")
            return
        }
        let title = "\(items[selectedIndex])  ⌄"
        attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: Theme.font(12.5),
                .foregroundColor: Theme.primary
            ]
        )
    }

    private func updateAppearance() {
        layer?.backgroundColor = (isHovering ? Theme.hoverFill : NSColor.clear).cgColor
        layer?.borderColor = (isHovering ? Theme.borderStrong : Theme.hairline).cgColor
    }

    override var intrinsicContentSize: NSSize {
        let title = items.indices.contains(selectedIndex) ? items[selectedIndex] : ""
        let measured = (title as NSString).size(withAttributes: [.font: Theme.font(12.5)])
        return NSSize(width: ceil(measured.width) + 38, height: 30)
    }
}

final class FlatSegmentedControl: NSView {
    private let stack = NSStackView()
    private var buttons: [FlatButton] = []
    private let items: [String]
    private(set) var selectedIndex: Int
    var onChange: ((Int) -> Void)?

    init(items: [String], selectedIndex: Int = 0, onChange: ((Int) -> Void)? = nil) {
        self.items = items
        self.selectedIndex = max(0, min(selectedIndex, max(0, items.count - 1)))
        self.onChange = onChange
        super.init(frame: .zero)

        wantsLayer = true
        layer?.backgroundColor = Theme.surface.cgColor
        layer?.borderColor = Theme.hairline.cgColor
        layer?.borderWidth = 1
        layer?.cornerRadius = 5
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 28).isActive = true

        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.distribution = .fillEqually
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2)
        ])

        for (index, title) in items.enumerated() {
            let button = FlatButton(
                title: title,
                style: index == self.selectedIndex ? .accent : .ghost,
                font: Theme.font(11, weight: .medium),
                height: 24
            ) { [weak self] in
                self?.select(index)
            }
            button.layer?.cornerRadius = 3
            buttons.append(button)
            stack.addArrangedSubview(button)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func select(_ index: Int, notify: Bool = true) {
        guard index >= 0, index < buttons.count else { return }
        selectedIndex = index
        for (buttonIndex, button) in buttons.enumerated() {
            button.style = buttonIndex == index ? .accent : .ghost
        }
        if notify {
            onChange?(index)
        }
    }
}

final class FlatToggle: NSView {
    private let knob = NSView()
    private(set) var isOn: Bool
    var onChange: ((Bool) -> Void)?

    init(isOn: Bool, onChange: ((Bool) -> Void)? = nil) {
        self.isOn = isOn
        self.onChange = onChange
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 36).isActive = true
        heightAnchor.constraint(equalToConstant: 20).isActive = true
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.borderWidth = 1

        knob.wantsLayer = true
        knob.layer?.backgroundColor = Theme.primary.cgColor
        knob.layer?.cornerRadius = 7
        addSubview(knob)
        updateAppearance()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        knob.frame = NSRect(x: isOn ? bounds.width - 17 : 3, y: 3, width: 14, height: 14)
    }

    override func mouseDown(with event: NSEvent) {
        isOn.toggle()
        onChange?(isOn)
        updateAppearance()
        needsLayout = true
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 49 || event.keyCode == 36 {
            isOn.toggle()
            onChange?(isOn)
            updateAppearance()
            needsLayout = true
        } else {
            super.keyDown(with: event)
        }
    }

    override var acceptsFirstResponder: Bool { true }

    private func updateAppearance() {
        layer?.backgroundColor = (isOn ? Theme.accent : Theme.surfaceRaised).cgColor
        layer?.borderColor = (isOn ? Theme.accent : Theme.hairline).cgColor
        setAccessibilityRole(.checkBox)
        setAccessibilityValue(isOn ? 1 : 0)
    }
}

final class BoxedTextField: NSView, NSTextFieldDelegate {
    let textField = NSTextField()
    private var hasError = false
    private var isFocused = false

    var stringValue: String {
        get { textField.stringValue }
        set { textField.stringValue = newValue }
    }

    var placeholder: String? {
        get { textField.placeholderString }
        set { textField.placeholderString = newValue }
    }

    init(placeholder: String? = nil, font: NSFont = Theme.font(13), alignment: NSTextAlignment = .left) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.backgroundColor = Theme.surfaceRaised.cgColor
        layer?.borderColor = Theme.hairline.cgColor
        layer?.borderWidth = 1
        layer?.cornerRadius = 4
        heightAnchor.constraint(equalToConstant: 30).isActive = true

        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.isBordered = false
        textField.isBezeled = false
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.textColor = Theme.primary
        textField.font = font
        textField.alignment = alignment
        textField.placeholderString = placeholder
        textField.usesSingleLineMode = true
        textField.lineBreakMode = .byClipping
        textField.delegate = self
        addSubview(textField)

        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            textField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            textField.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setError(_ value: Bool) {
        hasError = value
        updateBorder()
    }

    func setEnabled(_ enabled: Bool) {
        textField.isEnabled = enabled
        textField.textColor = enabled ? Theme.primary : Theme.tertiary
    }

    func controlTextDidBeginEditing(_ obj: Notification) {
        isFocused = true
        updateBorder()
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        isFocused = false
        updateBorder()
    }

    private func updateBorder() {
        if hasError {
            layer?.borderColor = Theme.borderStrong.cgColor
        } else if isFocused {
            layer?.borderColor = Theme.accent.cgColor
        } else {
            layer?.borderColor = Theme.hairline.cgColor
        }
    }
}

final class FormField: NSView {
    let input: BoxedTextField
    private let titleLabel: NSTextField

    init(
        title: String,
        placeholder: String? = nil,
        font: NSFont = Theme.font(13)
    ) {
        titleLabel = label(title, font: Theme.font(10.5), color: Theme.secondary)
        input = BoxedTextField(placeholder: placeholder, font: font)
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 50).isActive = true

        addSubview(titleLabel)
        addSubview(input)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            titleLabel.topAnchor.constraint(equalTo: topAnchor),
            input.leadingAnchor.constraint(equalTo: leadingAnchor),
            input.trailingAnchor.constraint(equalTo: trailingAnchor),
            input.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 5),
            input.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var stringValue: String {
        get { input.stringValue }
        set { input.stringValue = newValue }
    }

    func setError(_ value: Bool) {
        input.setError(value)
    }

    func setTitle(_ text: String) {
        titleLabel.stringValue = text
    }
}

func sectionLabel(_ text: String) -> NSTextField {
    let field = label(text.uppercased(), font: Theme.font(10, weight: .semibold), color: Theme.secondary)
    field.attributedStringValue = NSAttributedString(
        string: text.uppercased(),
        attributes: [
            .font: Theme.font(10, weight: .semibold),
            .foregroundColor: Theme.secondary,
            .kern: 0.8
        ]
    )
    return field
}

func bodyLabel(_ text: String, color: NSColor = Theme.secondary, size: CGFloat = 11.5) -> NSTextField {
    let field = label(text, font: Theme.font(size), color: color)
    field.preferredMaxLayoutWidth = 440
    return field
}
