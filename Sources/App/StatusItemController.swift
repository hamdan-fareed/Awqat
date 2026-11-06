import AppKit

final class StatusItemController: NSObject {
    private let model: AppModel
    private let onOpen: () -> Void
    private let onSettings: () -> Void
    private var statusItem: NSStatusItem?

    init(model: AppModel, onOpen: @escaping () -> Void, onSettings: @escaping () -> Void) {
        self.model = model
        self.onOpen = onOpen
        self.onSettings = onSettings
        super.init()
    }

    var currentTitle: String {
        statusItem?.button?.title ?? ""
    }

    var currentMenuTitles: [String] {
        statusItem?.menu?.items.map(\.title) ?? []
    }

    func refresh() {
        guard model.settings.menuBar.isEnabled else {
            removeStatusItem()
            return
        }

        if statusItem == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            item.button?.font = Theme.mono(11.5)
            item.button?.imagePosition = .noImage
            statusItem = item
        }

        guard let statusItem else { return }
        let timeZone = model.settings.location?.timeZone ?? .current
        let title: String
        switch model.settings.menuBar.titleMode {
        case .allFive:
            title = MenuBarSummary.allFiveTitle(day: model.day, timeZone: timeZone)
        case .nextPrayer:
            title = MenuBarSummary.nextTitle(next: model.next, timeZone: timeZone)
        }

        statusItem.button?.title = title
        statusItem.button?.toolTip = fullTooltip(timeZone: timeZone)
        statusItem.menu = makeMenu(timeZone: timeZone)
    }

    private func removeStatusItem() {
        guard let statusItem else { return }
        NSStatusBar.system.removeStatusItem(statusItem)
        self.statusItem = nil
    }

    private func fullTooltip(timeZone: TimeZone) -> String {
        guard let day = model.day else {
            return model.settings.location == nil ? "Set a location in Awqat" : "Prayer times unavailable"
        }
        return Salah.allCases.compactMap { salah in
            guard let time = day.time(for: salah) else { return nil }
            return "\(salah.displayName) \(TimeFormatting.timeString(time, timeZone: timeZone))"
        }
        .joined(separator: "   ")
    }

    private func makeMenu(timeZone: TimeZone) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.font = Theme.font(12.5)

        if let day = model.day {
            for salah in Salah.allCases {
                guard let time = day.time(for: salah) else { continue }
                let title = "\(salah.displayName)   \(TimeFormatting.timeString(time, timeZone: timeZone))"
                let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                item.isEnabled = false
                item.attributedTitle = NSAttributedString(
                    string: title,
                    attributes: [
                        .font: Theme.mono(12),
                        .foregroundColor: Theme.primary
                    ]
                )
                menu.addItem(item)
            }
        } else if model.settings.location == nil {
            let item = NSMenuItem(title: "Set location…", action: #selector(openSettingsAction), keyEquivalent: "")
            item.target = self
            menu.addItem(item)
        } else {
            let item = NSMenuItem(title: "Times unavailable", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }

        menu.addItem(.separator())

        let openItem = NSMenuItem(title: "Open Awqat", action: #selector(openAction), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettingsAction), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Awqat", action: #selector(quitAction), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    @objc private func openAction() {
        onOpen()
    }

    @objc private func openSettingsAction() {
        onSettings()
    }

    @objc private func quitAction() {
        NSApp.terminate(nil)
    }
}
