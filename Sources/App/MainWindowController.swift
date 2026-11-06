import AppKit

final class MainWindowController: NSWindowController {
    private let mainView: MainView

    init(model: AppModel, onSettings: @escaping () -> Void) {
        mainView = MainView(onSettings: onSettings)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = Theme.appName
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.backgroundColor = Theme.background
        window.isMovableByWindowBackground = true
        window.appearance = NSAppearance(named: .darkAqua)
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.contentView = mainView
        window.setContentSize(NSSize(width: 420, height: 620))
        window.center()

        super.init(window: window)
        render(model: model)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func render(model: AppModel) {
        mainView.render(
            settings: model.settings,
            day: model.day,
            next: model.next,
            errorMessage: model.errorMessage
        )
    }
}

private final class HoverLabel: NSTextField {
    var onHover: ((Bool) -> Void)?
    private var trackingArea: NSTrackingArea?
    private let baseColor: NSColor

    init(text: String, font: NSFont, color: NSColor) {
        self.baseColor = color
        super.init(frame: .zero)
        stringValue = text
        self.font = font
        textColor = color
        isEditable = false
        isBordered = false
        drawsBackground = false
        isSelectable = false
        lineBreakMode = .byClipping
        translatesAutoresizingMaskIntoConstraints = false
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
        textColor = Theme.primary
        onHover?(true)
    }

    override func mouseExited(with event: NSEvent) {
        textColor = baseColor
        onHover?(false)
    }
}

final class PeriodRowView: NSView {
    let period: IslamicPeriod
    private let nameLabel: HoverLabel
    private let timeLabel = NSTextField(labelWithString: "")
    private let tomorrowLabel = NSTextField(labelWithString: "tomorrow")
    private let manualDot = NSView()
    private let isNext: Bool

    init(
        entry: ScheduleEntry,
        isNext: Bool,
        manualScope: SalahOverrideScope?,
        timeZone: TimeZone,
        onHover: @escaping (IslamicPeriod, NSView, Bool) -> Void
    ) {
        self.period = entry.period
        self.isNext = isNext

        let nameColor = isNext ? Theme.primary : (entry.period.isSalah ? Theme.primary : Theme.secondary)
        let nameFont = entry.period.isSalah ? Theme.font(15, weight: .medium) : Theme.font(14)
        nameLabel = HoverLabel(text: entry.period.displayName, font: nameFont, color: nameColor)

        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        heightAnchor.constraint(equalToConstant: 46).isActive = true

        if isNext {
            layer?.backgroundColor = Theme.accent.cgColor
        }

        nameLabel.onHover = { [weak self] hovering in
            guard let self else { return }
            onHover(self.period, self.nameLabel, hovering)
        }
        nameLabel.setAccessibilityLabel(entry.period.displayName)
        nameLabel.setAccessibilityHelp(entry.period.detail)

        timeLabel.stringValue = TimeFormatting.timeString(entry.time, timeZone: timeZone)
        timeLabel.font = Theme.mono(entry.period.isSalah ? 15 : 14)
        timeLabel.textColor = isNext ? Theme.primary : (entry.period.isSalah ? Theme.primary : Theme.secondary)
        timeLabel.alignment = .right
        timeLabel.translatesAutoresizingMaskIntoConstraints = false

        tomorrowLabel.font = Theme.font(9.5)
        tomorrowLabel.textColor = Theme.secondary
        tomorrowLabel.alignment = .right
        tomorrowLabel.translatesAutoresizingMaskIntoConstraints = false
        tomorrowLabel.stringValue = entry.dayOffset == 0 ? "" : "tomorrow"
        tomorrowLabel.isHidden = entry.dayOffset == 0

        manualDot.translatesAutoresizingMaskIntoConstraints = false
        manualDot.wantsLayer = true
        manualDot.layer?.backgroundColor = Theme.primary.withAlphaComponent(0.72).cgColor
        manualDot.layer?.cornerRadius = 2.5
        manualDot.isHidden = manualScope == nil
        manualDot.setAccessibilityLabel(
            manualScope == .today ? "Manual time today" : (manualScope == .daily ? "Manual time daily" : "Calculated time")
        )

        let timeStack = NSStackView(views: [timeLabel, tomorrowLabel])
        timeStack.orientation = .vertical
        timeStack.alignment = .trailing
        timeStack.spacing = 0
        timeStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(nameLabel)
        addSubview(timeStack)
        addSubview(manualDot)

        NSLayoutConstraint.activate([
            nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            nameLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: manualDot.leadingAnchor, constant: -14),

            manualDot.widthAnchor.constraint(equalToConstant: 5),
            manualDot.heightAnchor.constraint(equalToConstant: 5),
            manualDot.centerYAnchor.constraint(equalTo: centerYAnchor),
            manualDot.trailingAnchor.constraint(equalTo: timeStack.leadingAnchor, constant: -8),

            timeStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            timeStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            timeStack.widthAnchor.constraint(greaterThanOrEqualToConstant: 58)
        ])

        let separator = makeHairline()
        separator.layer?.backgroundColor = (isNext ? Theme.primary.withAlphaComponent(0.14) : Theme.hairline).cgColor
        addSubview(separator)
        NSLayoutConstraint.activate([
            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class MainView: NSView {
    var displayTimeZone: TimeZone = .current

    private let onSettings: () -> Void
    private let locationLabel = NSTextField(labelWithString: "Awqat")
    private let dateLabel = NSTextField(labelWithString: "")
    private let contentStack = NSStackView()
    private let footerLabel = NSTextField(labelWithString: "")
    private let tooltipPresenter = TooltipPresenter()
    private let settingsButton: NSButton
    private var pendingTooltip: DispatchWorkItem?

    init(onSettings: @escaping () -> Void) {
        self.onSettings = onSettings
        settingsButton = NSButton(
            image: NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Settings")!,
            target: nil,
            action: nil
        )
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = Theme.background.cgColor

        settingsButton.isBordered = false
        settingsButton.focusRingType = .none
        settingsButton.contentTintColor = Theme.primary
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        settingsButton.target = self
        settingsButton.action = #selector(openSettings)
        settingsButton.toolTip = "Settings"
        settingsButton.widthAnchor.constraint(equalToConstant: 28).isActive = true
        settingsButton.heightAnchor.constraint(equalToConstant: 28).isActive = true

        locationLabel.font = Theme.font(15, weight: .semibold)
        locationLabel.textColor = Theme.primary
        locationLabel.translatesAutoresizingMaskIntoConstraints = false

        dateLabel.font = Theme.font(11.5)
        dateLabel.textColor = Theme.secondary
        dateLabel.translatesAutoresizingMaskIntoConstraints = false

        let headerStack = NSStackView(views: [locationLabel, dateLabel])
        headerStack.orientation = .vertical
        headerStack.alignment = .leading
        headerStack.spacing = 3
        headerStack.translatesAutoresizingMaskIntoConstraints = false

        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 0
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        footerLabel.font = Theme.font(10.5)
        footerLabel.textColor = Theme.tertiary
        footerLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(headerStack)
        addSubview(settingsButton)
        addSubview(contentStack)
        addSubview(footerLabel)

        NSLayoutConstraint.activate([
            headerStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            headerStack.topAnchor.constraint(equalTo: topAnchor, constant: 31),

            settingsButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -22),
            settingsButton.centerYAnchor.constraint(equalTo: headerStack.centerYAnchor),

            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            contentStack.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 16),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: footerLabel.topAnchor, constant: -10),

            footerLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            footerLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func render(settings: AppSettings, day: PrayerDay?, next: NextPrayer?, errorMessage: String?) {
        tooltipPresenter.hide()
        pendingTooltip?.cancel()
        pendingTooltip = nil

        displayTimeZone = settings.location?.timeZone ?? .current

        if let location = settings.location {
            let labelText = location.label.trimmingCharacters(in: .whitespacesAndNewlines)
            locationLabel.stringValue = labelText.isEmpty ? "My Location" : labelText
            dateLabel.stringValue = day.map { TimeFormatting.dateString($0.date, timeZone: location.timeZone) } ?? "Times unavailable"
        } else {
            locationLabel.stringValue = "Awqat"
            dateLabel.stringValue = "No location set"
        }

        for view in contentStack.arrangedSubviews {
            contentStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        if let errorMessage {
            footerLabel.stringValue = ""
            addStateView(
                title: "Times unavailable",
                body: errorMessage,
                buttonTitle: "Open Settings"
            )
        } else if let day {
            footerLabel.attributedStringValue = footerText()
            addRows(day: day, next: next)
        } else {
            footerLabel.stringValue = ""
            addStateView(
                title: "Set your location",
                body: "Enter your latitude, longitude, and time zone manually. Awqat never detects your location.",
                buttonTitle: "Set Location"
            )
        }
    }

    private func addRows(day: PrayerDay, next: NextPrayer?) {
        for (index, entry) in day.entries.enumerated() {
            let showNext = next?.salah == entry.period.salah && next?.isTomorrow == false
            let manualScope = entry.period.salah.flatMap { day.manualScopes[$0] }
            let row = PeriodRowView(
                entry: entry,
                isNext: showNext,
                manualScope: manualScope,
                timeZone: displayTimeZone
            ) { [weak self] period, anchor, hovering in
                self?.handleHover(period: period, anchor: anchor, hovering: hovering)
            }
            contentStack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true

            if index < day.entries.count - 1 {
                // The row itself carries the hairline, keeping the list free of extra containers.
            }
        }
    }

    private func addStateView(title: String, body: String, buttonTitle: String) {
        let titleLabel = label(title, font: Theme.font(20, weight: .semibold), color: Theme.primary)
        let descriptionLabel = bodyLabel(body, color: Theme.secondary, size: 12.5)
        descriptionLabel.alignment = .center
        descriptionLabel.preferredMaxLayoutWidth = 310

        let button = FlatButton(title: buttonTitle, style: .accent) { [weak self] in
            self?.onSettings()
        }

        let stack = NSStackView(views: [titleLabel, descriptionLabel, button])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 420),
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: -20),
            stack.widthAnchor.constraint(lessThanOrEqualTo: container.widthAnchor)
        ])

        contentStack.addArrangedSubview(container)
        container.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
    }

    private func handleHover(period: IslamicPeriod, anchor: NSView, hovering: Bool) {
        pendingTooltip?.cancel()
        pendingTooltip = nil
        if !hovering {
            tooltipPresenter.hide()
            return
        }

        let item = DispatchWorkItem { [weak self, weak anchor] in
            guard let self, let anchor, anchor.window != nil else { return }
            self.tooltipPresenter.show(period: period, anchor: anchor)
        }
        pendingTooltip = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: item)
    }

    private func footerText() -> NSAttributedString {
        let full = "Hover a name for its meaning     ●  manual time"
        let result = NSMutableAttributedString(
            string: full,
            attributes: [
                .font: Theme.font(10.5),
                .foregroundColor: Theme.tertiary
            ]
        )
        if let dotRange = full.range(of: "●") {
            result.addAttribute(
                .foregroundColor,
                value: Theme.primary.withAlphaComponent(0.72),
                range: NSRange(dotRange, in: full)
            )
        }
        return result
    }

    @objc private func openSettings() {
        onSettings()
    }
}

final class TooltipPresenter {
    private let panel: NSPanel
    private let tooltipView: TooltipView
    private let textAttributes: [NSAttributedString.Key: Any]
    private let maxWidth: CGFloat = 276

    init() {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 2
        textAttributes = [
            .font: Theme.font(12),
            .foregroundColor: Theme.primary,
            .paragraphStyle: paragraph
        ]

        tooltipView = TooltipView()
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: maxWidth, height: 80),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.hidesOnDeactivate = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.transient, .ignoresCycle]
        panel.animationBehavior = .none
        panel.contentView = tooltipView
    }

    func show(period: IslamicPeriod, anchor: NSView) {
        guard let window = anchor.window else { return }

        let attributed = NSAttributedString(string: period.detail, attributes: textAttributes)
        let textRect = attributed.boundingRect(
            with: NSSize(width: maxWidth - 24, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        let contentSize = NSSize(
            width: maxWidth,
            height: ceil(textRect.height) + 20
        )

        tooltipView.frame = NSRect(origin: .zero, size: contentSize)
        tooltipView.label.attributedStringValue = attributed
        tooltipView.label.frame = NSRect(
            x: 12,
            y: 10,
            width: contentSize.width - 24,
            height: contentSize.height - 20
        )

        let anchorRectInWindow = anchor.convert(anchor.bounds, to: nil)
        let anchorRectOnScreen = window.convertToScreen(anchorRectInWindow)
        let visible = (window.screen ?? NSScreen.main)?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        var x = anchorRectOnScreen.minX
        x = max(visible.minX + 8, min(x, visible.maxX - contentSize.width - 8))

        var y = anchorRectOnScreen.minY - contentSize.height - 8
        if y < visible.minY + 8 {
            y = anchorRectOnScreen.maxY + 8
        }
        y = max(visible.minY + 8, min(y, visible.maxY - contentSize.height - 8))

        panel.setFrame(
            NSRect(x: x, y: y, width: contentSize.width, height: contentSize.height),
            display: true
        )
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }
}

private final class TooltipView: NSView {
    let label = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = Theme.background.cgColor
        layer?.borderColor = Theme.accent.cgColor
        layer?.borderWidth = 1
        layer?.cornerRadius = 4

        label.isEditable = false
        label.isBordered = false
        label.drawsBackground = false
        label.isSelectable = false
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        addSubview(label)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
