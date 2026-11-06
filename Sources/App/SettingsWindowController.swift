import AppKit

final class ManualTimeRowView: NSView {
    let salah: Salah
    private let modeControl: FlatSegmentedControl
    private let timeField: BoxedTextField
    private let calculatedLabel: NSTextField
    private let calculatedTime: Date?
    private let timeZone: TimeZone

    init(
        salah: Salah,
        override: SalahOverride?,
        calculatedTime: Date?,
        timeZone: TimeZone
    ) {
        self.salah = salah
        self.calculatedTime = calculatedTime
        self.timeZone = timeZone

        let initialMode: Int
        switch override?.scope {
        case .today: initialMode = 1
        case .daily: initialMode = 2
        case nil: initialMode = 0
        }

        modeControl = FlatSegmentedControl(
            items: ["Auto", "Today", "Daily"],
            selectedIndex: initialMode
        )
        timeField = BoxedTextField(placeholder: "HH:mm", font: Theme.mono(12))
        calculatedLabel = label("", font: Theme.font(9.5), color: Theme.tertiary)

        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 50).isActive = true

        let nameLabel = label(salah.displayName, font: Theme.font(13, weight: .medium), color: Theme.primary)
        nameLabel.widthAnchor.constraint(equalToConstant: 66).isActive = true

        let calcText: String
        if let calculatedTime {
            calcText = "Calc \(TimeFormatting.timeString(calculatedTime, timeZone: timeZone))"
        } else {
            calcText = "Calc --:--"
        }
        calculatedLabel.stringValue = calcText

        if let override {
            timeField.stringValue = TimeFormatting.overrideTimeString(
                hour: override.hour,
                minute: override.minute,
                timeZone: timeZone
            )
        } else if let calculatedTime {
            timeField.stringValue = TimeFormatting.timeString(calculatedTime, timeZone: timeZone)
        }

        timeField.setEnabled(initialMode != 0)
        modeControl.onChange = { [weak self] index in
            self?.modeChanged(index)
        }

        addSubview(nameLabel)
        addSubview(modeControl)
        addSubview(timeField)
        addSubview(calculatedLabel)

        NSLayoutConstraint.activate([
            nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            nameLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            modeControl.leadingAnchor.constraint(equalTo: nameLabel.trailingAnchor, constant: 12),
            modeControl.centerYAnchor.constraint(equalTo: centerYAnchor),
            modeControl.widthAnchor.constraint(equalToConstant: 165),

            timeField.leadingAnchor.constraint(equalTo: modeControl.trailingAnchor, constant: 12),
            timeField.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -5),
            timeField.widthAnchor.constraint(equalToConstant: 92),

            calculatedLabel.leadingAnchor.constraint(equalTo: timeField.leadingAnchor),
            calculatedLabel.topAnchor.constraint(equalTo: timeField.bottomAnchor, constant: 1),
            calculatedLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func makeOverride(dateKey: String?) -> (SalahOverride?, String?) {
        guard modeControl.selectedIndex != 0 else {
            timeField.setError(false)
            return (nil, nil)
        }

        guard let parsed = TimeFormatting.parseTime(timeField.stringValue) else {
            timeField.setError(true)
            return (nil, "Enter a valid time for \(salah.displayName).")
        }

        timeField.setError(false)
        let scope: SalahOverrideScope = modeControl.selectedIndex == 1 ? .today : .daily

        guard scope == .daily || dateKey != nil else {
            return (nil, "Set a location before using a Today-only time.")
        }

        return (
            SalahOverride(
                scope: scope,
                hour: parsed.hour,
                minute: parsed.minute,
                dateKey: scope == .today ? dateKey : nil
            ),
            nil
        )
    }

    func reset() {
        modeControl.select(0, notify: false)
        modeChanged(0)
    }

    private func modeChanged(_ index: Int) {
        if index == 0 {
            if let calculatedTime {
                timeField.stringValue = TimeFormatting.timeString(calculatedTime, timeZone: timeZone)
            }
            timeField.setEnabled(false)
            timeField.setError(false)
        } else {
            timeField.setEnabled(true)
            if timeField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let calculatedTime {
                timeField.stringValue = TimeFormatting.timeString(calculatedTime, timeZone: timeZone)
            }
        }
    }
}

final class SettingsWindowController: NSWindowController {
    private let sourceSettings: AppSettings
    private let currentDay: PrayerDay?
    private let onSave: (AppSettings) -> Void
    private let onCancel: () -> Void

    private let timeZones: [String]

    private let labelField = FormField(title: "Label", placeholder: "My Location")
    private let latitudeField = FormField(title: "Latitude", placeholder: "21.4225", font: Theme.mono(12.5))
    private let longitudeField = FormField(title: "Longitude", placeholder: "39.8262", font: Theme.mono(12.5))
    private let timeZonePopup: FlatPopupButton
    private let fajrAngleField = FormField(title: "Fajr angle (°)", placeholder: "18.0", font: Theme.mono(12.5))
    private let ishaBasisControl = FlatSegmentedControl(items: ["Angle", "Minutes"], selectedIndex: 0)
    private let ishaValueField = FormField(title: "Isha value", placeholder: "17.0", font: Theme.mono(12.5))
    private let highLatitudePopup: FlatPopupButton
    private let presetPopup: FlatPopupButton
    private let menuModeControl = FlatSegmentedControl(items: ["All five", "Next prayer"], selectedIndex: 0)
    private let errorLabel = NSTextField(labelWithString: "")

    private var manualRows: [ManualTimeRowView] = []
    private var menuToggle: FlatToggle!

    init(
        settings: AppSettings,
        day: PrayerDay?,
        onSave: @escaping (AppSettings) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.sourceSettings = settings
        self.currentDay = day
        self.onSave = onSave
        self.onCancel = onCancel

        var zones = TimeZone.knownTimeZoneIdentifiers
        let preferredZones = [TimeZone.current.identifier, settings.location?.timeZoneID].compactMap { $0 }
        for zone in preferredZones where !zones.contains(zone) {
            zones.append(zone)
        }
        zones.sort()
        self.timeZones = zones

        let selectedZone = settings.location?.timeZoneID ?? TimeZone.current.identifier
        let zoneIndex = zones.firstIndex(of: selectedZone) ?? 0
        timeZonePopup = FlatPopupButton(items: zones, selectedIndex: zoneIndex)

        let presetIndex = CalculationPreset.allCases.firstIndex(of: settings.calculation.preset) ?? 0
        presetPopup = FlatPopupButton(
            items: CalculationPreset.allCases.map(\.displayName),
            selectedIndex: presetIndex
        )

        let highIndex = HighLatitudeOption.allCases.firstIndex(of: settings.calculation.highLatitude) ?? 0
        highLatitudePopup = FlatPopupButton(
            items: HighLatitudeOption.allCases.map(\.displayName),
            selectedIndex: highIndex
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 720),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.backgroundColor = Theme.background
        window.appearance = NSAppearance(named: .darkAqua)
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.setContentSize(NSSize(width: 540, height: 720))

        super.init(window: window)
        buildInterface()
        loadValues()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present(asSheetFor parent: NSWindow) {
        parent.beginSheet(window!, completionHandler: nil)
        window?.makeKeyAndOrderFront(nil)
    }

    func dismiss() {
        guard let window else { return }
        if let parent = window.sheetParent {
            parent.endSheet(window)
        } else {
            window.orderOut(nil)
        }
    }

    private func buildInterface() {
        guard let window, let content = window.contentView else { return }
        content.wantsLayer = true
        content.layer?.backgroundColor = Theme.background.cgColor

        let title = label("Settings", font: Theme.font(19, weight: .semibold), color: Theme.primary)

        let cancel = FlatButton(title: "Cancel", style: .ghost, height: 30) { [weak self] in
            self?.cancel()
        }
        cancel.keyEquivalent = "\u{1b}"

        let save = FlatButton(title: "Save", style: .accent, height: 30) { [weak self] in
            self?.save()
        }
        save.keyEquivalent = "\r"

        let buttonRow = NSStackView(views: [cancel, save])
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 8
        buttonRow.translatesAutoresizingMaskIntoConstraints = false

        errorLabel.font = Theme.font(11)
        errorLabel.textColor = Theme.primary
        errorLabel.maximumNumberOfLines = 2
        errorLabel.lineBreakMode = .byWordWrapping
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        errorLabel.stringValue = ""

        let scroll = NSScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.scrollerStyle = .overlay
        scroll.contentView.drawsBackground = false

        let document = FlippedView()
        document.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = document

        content.addSubview(title)
        content.addSubview(buttonRow)
        content.addSubview(errorLabel)
        content.addSubview(scroll)

        NSLayoutConstraint.activate([
            title.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            title.topAnchor.constraint(equalTo: content.topAnchor, constant: 24),

            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            scroll.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 16),
            scroll.bottomAnchor.constraint(equalTo: errorLabel.topAnchor, constant: -10),

            errorLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            errorLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            errorLabel.bottomAnchor.constraint(equalTo: buttonRow.topAnchor, constant: -12),
            errorLabel.heightAnchor.constraint(equalToConstant: 30),

            buttonRow.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            buttonRow.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20),

            document.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor),
            document.trailingAnchor.constraint(equalTo: scroll.contentView.trailingAnchor),
            document.topAnchor.constraint(equalTo: scroll.contentView.topAnchor),
            document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor)
        ])

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 4),
            stack.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -4),
            stack.topAnchor.constraint(equalTo: document.topAnchor, constant: 4),
            stack.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -16)
        ])

        addLocationSection(to: stack)
        addSalahSection(to: stack)
        addCalculationSection(to: stack)
        addMenuBarSection(to: stack)
        addDisclaimer(to: stack)
    }

    private func addFullWidth(_ view: NSView, to stack: NSStackView) {
        stack.addArrangedSubview(view)
        view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
    }

    private func addLocationSection(to stack: NSStackView) {
        let latLon = NSStackView(views: [latitudeField, longitudeField])
        latLon.orientation = .horizontal
        latLon.spacing = 12
        latLon.distribution = .fillEqually
        latLon.translatesAutoresizingMaskIntoConstraints = false

        let useSystem = FlatButton(title: "Use system", style: .outline, height: 30) { [weak self] in
            guard let self, let index = self.timeZones.firstIndex(of: TimeZone.current.identifier) else { return }
            self.timeZonePopup.setSelectedIndex(index)
        }
        useSystem.widthAnchor.constraint(equalToConstant: 96).isActive = true

        let zoneRow = NSStackView(views: [timeZonePopup, useSystem])
        zoneRow.orientation = .horizontal
        zoneRow.spacing = 10
        zoneRow.alignment = .centerY
        zoneRow.translatesAutoresizingMaskIntoConstraints = false
        timeZonePopup.widthAnchor.constraint(equalToConstant: 370).isActive = true

        let zoneForm = NSStackView(views: [label("Time zone", font: Theme.font(10.5), color: Theme.secondary), zoneRow])
        zoneForm.orientation = .vertical
        zoneForm.spacing = 5
        zoneForm.alignment = .leading
        zoneForm.translatesAutoresizingMaskIntoConstraints = false

        let section = NSStackView(views: [
            sectionLabel("Location"),
            labelField,
            latLon,
            zoneForm
        ])
        section.orientation = .vertical
        section.alignment = .leading
        section.spacing = 10
        section.setCustomSpacing(6, after: section.arrangedSubviews[0])
        section.translatesAutoresizingMaskIntoConstraints = false

        labelField.widthAnchor.constraint(equalTo: section.widthAnchor).isActive = true
        latLon.widthAnchor.constraint(equalTo: section.widthAnchor).isActive = true
        zoneForm.widthAnchor.constraint(equalTo: section.widthAnchor).isActive = true

        addFullWidth(section, to: stack)
    }

    private func addSalahSection(to stack: NSStackView) {
        let intro = bodyLabel(
            "Leave a salah on Auto to use the calculated time. Today changes only the current date. Daily repeats a fixed clock time every day.",
            color: Theme.secondary,
            size: 11.5
        )
        intro.preferredMaxLayoutWidth = 470

        var views: [NSView] = [sectionLabel("Salah times"), intro]
        for salah in Salah.allCases {
            let row = ManualTimeRowView(
                salah: salah,
                override: sourceSettings.overrides[salah],
                calculatedTime: currentDay?.basePrayers[salah],
                timeZone: sourceSettings.location?.timeZone ?? .current
            )
            manualRows.append(row)
            views.append(row)
        }

        let reset = FlatButton(title: "Reset all to calculated", style: .outline, height: 30) { [weak self] in
            self?.resetManualTimes()
        }

        let note = bodyLabel(
            "Manual Fajr and Maghrib also shift Islamic midnight and the last third. Daily fixed times do not follow seasonal changes or DST.",
            color: Theme.tertiary,
            size: 10.5
        )
        note.preferredMaxLayoutWidth = 470

        views.append(reset)
        views.append(note)

        let section = NSStackView(views: views)
        section.orientation = .vertical
        section.alignment = .leading
        section.spacing = 8
        section.translatesAutoresizingMaskIntoConstraints = false
        section.setCustomSpacing(6, after: section.arrangedSubviews[0])
        addFullWidth(section, to: stack)
        for row in manualRows {
            row.widthAnchor.constraint(equalTo: section.widthAnchor).isActive = true
        }
    }

    private func addCalculationSection(to stack: NSStackView) {
        presetPopup.widthAnchor.constraint(equalToConstant: 250).isActive = true
        presetPopup.onSelect = { [weak self] index in
            self?.applyPreset(index: index)
        }

        let presetRow = fieldRow(title: "Calculation preset", control: presetPopup)
        fajrAngleField.widthAnchor.constraint(equalToConstant: 130).isActive = true
        ishaValueField.widthAnchor.constraint(equalToConstant: 130).isActive = true
        ishaBasisControl.widthAnchor.constraint(equalToConstant: 180).isActive = true
        ishaBasisControl.onChange = { [weak self] index in
            self?.updateIshaValueField(for: index)
        }

        let angles = NSStackView(views: [fajrAngleField, makeIshaValueGroup()])
        angles.orientation = .horizontal
        angles.spacing = 20
        angles.alignment = .top
        angles.translatesAutoresizingMaskIntoConstraints = false

        highLatitudePopup.widthAnchor.constraint(equalToConstant: 250).isActive = true
        let highRow = fieldRow(title: "High-latitude rule", control: highLatitudePopup)

        let asr = label("Asr: Hanbali — shadow equals object height", font: Theme.font(11.5), color: Theme.secondary)

        let note = bodyLabel(
            "Fajr 18° / Isha 17° is the default Hanbali approximation. Hanbali Isha begins at red twilight; use the preset or edit salah times to match your masjid.",
            color: Theme.tertiary,
            size: 10.5
        )
        note.preferredMaxLayoutWidth = 470

        let section = NSStackView(views: [
            sectionLabel("Calculation"),
            presetRow,
            angles,
            highRow,
            asr,
            note
        ])
        section.orientation = .vertical
        section.alignment = .leading
        section.spacing = 10
        section.setCustomSpacing(6, after: section.arrangedSubviews[0])
        section.translatesAutoresizingMaskIntoConstraints = false

        presetRow.widthAnchor.constraint(equalTo: section.widthAnchor).isActive = true
        highRow.widthAnchor.constraint(equalTo: section.widthAnchor).isActive = true
        addFullWidth(section, to: stack)
    }

    private func makeIshaValueGroup() -> NSView {
        let caption = label("Isha basis / value", font: Theme.font(10.5), color: Theme.secondary)
        let stack = NSStackView(views: [caption, ishaBasisControl, ishaValueField])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }

    private func fieldRow(title: String, control: NSView) -> NSView {
        let row = NSStackView(views: [
            label(title, font: Theme.font(10.5), color: Theme.secondary),
            control
        ])
        row.orientation = .horizontal
        row.spacing = 12
        row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false
        return row
    }

    private func addMenuBarSection(to stack: NSStackView) {
        let toggle = FlatToggle(isOn: sourceSettings.menuBar.isEnabled) { _ in }
        menuToggle = toggle

        let toggleLabel = label("Show in menu bar", font: Theme.font(13), color: Theme.primary)
        let toggleRow = NSStackView(views: [toggleLabel, toggle])
        toggleRow.orientation = .horizontal
        toggleRow.spacing = 12
        toggleRow.alignment = .centerY
        toggleRow.translatesAutoresizingMaskIntoConstraints = false

        menuModeControl.widthAnchor.constraint(equalToConstant: 200).isActive = true
        menuModeControl.select(sourceSettings.menuBar.titleMode == .allFive ? 0 : 1, notify: false)

        let modeRow = fieldRow(title: "Menu bar title", control: menuModeControl)

        let note = bodyLabel(
            "The menu bar lists only Fajr, Dhuhr, Asr, Maghrib, and Isha. All five shows a compact timetable; Next prayer shows a narrower item.",
            color: Theme.tertiary,
            size: 10.5
        )
        note.preferredMaxLayoutWidth = 470

        let section = NSStackView(views: [
            sectionLabel("Menu bar"),
            toggleRow,
            modeRow,
            note
        ])
        section.orientation = .vertical
        section.alignment = .leading
        section.spacing = 10
        section.setCustomSpacing(6, after: section.arrangedSubviews[0])
        section.translatesAutoresizingMaskIntoConstraints = false
        toggleRow.widthAnchor.constraint(equalTo: section.widthAnchor).isActive = true
        modeRow.widthAnchor.constraint(equalTo: section.widthAnchor).isActive = true
        addFullWidth(section, to: stack)
    }

    private func addDisclaimer(to stack: NSStackView) {
        let note = bodyLabel(
            "Times are astronomical estimates. Confirm with your local masjid. Calculations by Adhan 1.5.0 (MIT). All data stays on this Mac.",
            color: Theme.tertiary,
            size: 10.5
        )
        note.preferredMaxLayoutWidth = 470
        addFullWidth(note, to: stack)
    }

    private func loadValues() {
        labelField.stringValue = sourceSettings.location?.label ?? ""
        if let location = sourceSettings.location {
            latitudeField.stringValue = String(format: "%.6f", location.latitude)
            longitudeField.stringValue = String(format: "%.6f", location.longitude)
        }
        fajrAngleField.stringValue = String(format: "%.1f", sourceSettings.calculation.fajrAngle)
        ishaBasisControl.select(sourceSettings.calculation.ishaBasis == .angle ? 0 : 1, notify: false)
        if sourceSettings.calculation.ishaBasis == .angle {
            ishaValueField.stringValue = String(format: "%.1f", sourceSettings.calculation.ishaAngle)
        } else {
            ishaValueField.stringValue = "\(sourceSettings.calculation.ishaMinutes)"
        }
        ishaValueField.input.setEnabled(true)
        updateIshaValueField(for: ishaBasisControl.selectedIndex, forceValue: false)
        presetPopup.setSelectedIndex(CalculationPreset.allCases.firstIndex(of: sourceSettings.calculation.preset) ?? 0)
        highLatitudePopup.setSelectedIndex(HighLatitudeOption.allCases.firstIndex(of: sourceSettings.calculation.highLatitude) ?? 0)
        menuModeControl.select(sourceSettings.menuBar.titleMode == .allFive ? 0 : 1, notify: false)
    }

    private func updateIshaValueField(for index: Int, forceValue: Bool = true) {
        if index == 0 {
            ishaValueField.setTitle("Isha angle (°)")
            if forceValue {
                ishaValueField.stringValue = "17.0"
            }
        } else {
            ishaValueField.setTitle("Isha minutes")
            if forceValue {
                ishaValueField.stringValue = "90"
            }
        }
        ishaValueField.input.setEnabled(true)
    }

    private func applyPreset(index: Int) {
        guard CalculationPreset.allCases.indices.contains(index) else { return }
        switch CalculationPreset.allCases[index] {
        case .hanbali:
            fajrAngleField.stringValue = "18.0"
            ishaBasisControl.select(0, notify: false)
            ishaValueField.stringValue = "17.0"
            updateIshaValueField(for: 0, forceValue: false)
        case .ummAlQura:
            fajrAngleField.stringValue = "18.5"
            ishaBasisControl.select(1, notify: false)
            ishaValueField.stringValue = "90"
            updateIshaValueField(for: 1, forceValue: false)
        case .custom:
            break
        }
    }

    private func resetManualTimes() {
        for row in manualRows {
            row.reset()
        }
    }

    private func cancel() {
        dismiss()
        onCancel()
    }

    private func save() {
        errorLabel.stringValue = ""
        var updated = sourceSettings

        let labelText = labelField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let latitudeText = latitudeField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let longitudeText = longitudeField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        if latitudeText.isEmpty && longitudeText.isEmpty {
            updated.location = nil
        } else if latitudeText.isEmpty || longitudeText.isEmpty {
            showError("Enter both latitude and longitude, or clear both.")
            return
        } else if let latitude = parseDouble(latitudeText), let longitude = parseDouble(longitudeText) {
            let zone = timeZones[timeZonePopup.selectedIndex]
            updated.location = LocationSettings(
                label: labelText.isEmpty ? "My Location" : labelText,
                latitude: latitude,
                longitude: longitude,
                timeZoneID: zone
            )
        } else {
            showError("Latitude and longitude must be numbers.")
            return
        }

        guard let fajrAngle = parseDouble(fajrAngleField.stringValue) else {
            showError("Fajr angle must be a number.")
            return
        }

        let ishaBasis: IshaBasis = ishaBasisControl.selectedIndex == 0 ? .angle : .minutes
        let ishaAngle: Double
        let ishaMinutes: Int

        if ishaBasis == .angle {
            guard let value = parseDouble(ishaValueField.stringValue) else {
                showError("Isha angle must be a number.")
                return
            }
            ishaAngle = value
            ishaMinutes = 90
        } else {
            guard let value = Int(ishaValueField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                showError("Isha minutes must be a whole number.")
                return
            }
            ishaAngle = 17.0
            ishaMinutes = value
        }

        let highLatitude = HighLatitudeOption.allCases[highLatitudePopup.selectedIndex]
        let preset = inferPreset(
            fajrAngle: fajrAngle,
            ishaBasis: ishaBasis,
            ishaAngle: ishaAngle,
            ishaMinutes: ishaMinutes
        )
        updated.calculation = CalculationSettings(
            preset: preset,
            fajrAngle: fajrAngle,
            ishaBasis: ishaBasis,
            ishaAngle: ishaAngle,
            ishaMinutes: ishaMinutes,
            highLatitude: highLatitude
        )

        updated.menuBar = MenuBarSettings(
            isEnabled: menuToggle.isOn,
            titleMode: menuModeControl.selectedIndex == 0 ? .allFive : .nextPrayer
        )

        let dateKey: String?
        if let location = updated.location {
            dateKey = PrayerCalculator.dateKey(for: Date(), timeZone: location.timeZone)
        } else {
            dateKey = nil
        }

        var overrides = SalahOverrides()
        for row in manualRows {
            let (override, error) = row.makeOverride(dateKey: dateKey)
            if let error {
                showError(error)
                return
            }
            switch row.salah {
            case .fajr: overrides.fajr = override
            case .dhuhr: overrides.dhuhr = override
            case .asr: overrides.asr = override
            case .maghrib: overrides.maghrib = override
            case .isha: overrides.isha = override
            }
        }
        updated.overrides = overrides

        let errors = SettingsValidation.validate(updated)
        if let first = errors.first {
            showError(first)
            return
        }

        dismiss()
        onSave(updated)
    }

    private func parseDouble(_ value: String) -> Double? {
        Double(value.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: "."))
    }

    private func inferPreset(
        fajrAngle: Double,
        ishaBasis: IshaBasis,
        ishaAngle: Double,
        ishaMinutes: Int
    ) -> CalculationPreset {
        if ishaBasis == .angle,
           abs(fajrAngle - 18.0) < 0.01,
           abs(ishaAngle - 17.0) < 0.01 {
            return .hanbali
        }
        if ishaBasis == .minutes,
           abs(fajrAngle - 18.5) < 0.01,
           ishaMinutes == 90 {
            return .ummAlQura
        }
        return .custom
    }

    private func showError(_ message: String) {
        errorLabel.stringValue = message
    }
}
