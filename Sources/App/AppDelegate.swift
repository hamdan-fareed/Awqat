import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = SettingsStore()
    private var model: AppModel!
    private var mainWindowController: MainWindowController!
    private var statusItemController: StatusItemController!
    private var settingsController: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.appearance = NSAppearance(named: .darkAqua)

        model = AppModel(store: store)
        mainWindowController = MainWindowController(model: model) { [weak self] in
            self?.showSettings()
        }
        statusItemController = StatusItemController(
            model: model,
            onOpen: { [weak self] in self?.showMainWindow() },
            onSettings: { [weak self] in self?.showSettings() }
        )

        buildMenu()
        model.onUpdate = { [weak self] in
            self?.refreshAll()
        }
        model.start()
        refreshAll()
        showMainWindow()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        model?.stop()
    }

    private func refreshAll() {
        mainWindowController.render(model: model)
        statusItemController.refresh()
        #if DEBUG
        writeDiagnosticsIfRequested()
        #endif
    }

    #if DEBUG
    private func writeDiagnosticsIfRequested() {
        guard let path = ProcessInfo.processInfo.environment["AWQAT_DIAGNOSTICS"] else { return }
        let timeZone = model.settings.location?.timeZone ?? .current
        let lines = [
            "menuBarEnabled=\(model.settings.menuBar.isEnabled)",
            "menuBarMode=\(model.settings.menuBar.titleMode.rawValue)",
            "statusTitle=\(statusItemController.currentTitle)",
            "statusMenu=\(statusItemController.currentMenuTitles.joined(separator: " | "))",
            "location=\(model.settings.location?.label ?? "none")",
            "error=\(model.errorMessage ?? "none")",
            "next=\(model.next.map { "\($0.salah.displayName) \(TimeFormatting.timeString($0.time, timeZone: timeZone))" } ?? "none")"
        ]
        try? lines.joined(separator: "\n").write(toFile: path, atomically: true, encoding: .utf8)
    }
    #endif

    private func showMainWindow() {
        guard let window = mainWindowController.window else { return }
        mainWindowController.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showSettings() {
        showMainWindow()
        guard settingsController == nil else {
            settingsController?.window?.makeKeyAndOrderFront(nil)
            return
        }

        guard let parent = mainWindowController.window else { return }
        let controller = SettingsWindowController(
            settings: model.settings,
            day: model.day,
            onSave: { [weak self] settings in
                guard let self else { return }
                self.settingsController = nil
                self.model.apply(settings)
                self.refreshAll()
            },
            onCancel: { [weak self] in
                self?.settingsController = nil
            }
        )
        settingsController = controller
        controller.present(asSheetFor: parent)
    }

    @objc private func showSettingsAction() {
        showSettings()
    }

    @objc private func showAbout() {
        let credits = NSMutableAttributedString(
            string: "A minimal native prayer-times app.\nCalculation by Adhan 1.5.0 (MIT).",
            attributes: [
                .font: Theme.font(11),
                .foregroundColor: NSColor.labelColor
            ]
        )
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: Theme.appName,
            .applicationVersion: "1.0.0",
            .credits: credits
        ])
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem(title: "Awqat", action: nil, keyEquivalent: "")
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu

        let about = NSMenuItem(title: "About Awqat", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        appMenu.addItem(about)
        appMenu.addItem(.separator())

        let settings = NSMenuItem(title: "Settings…", action: #selector(showSettingsAction), keyEquivalent: ",")
        settings.target = self
        appMenu.addItem(settings)
        appMenu.addItem(.separator())

        let hide = NSMenuItem(title: "Hide Awqat", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        hide.target = NSApp
        appMenu.addItem(hide)

        let hideOthers = NSMenuItem(
            title: "Hide Others",
            action: #selector(NSApplication.hideOtherApplications(_:)),
            keyEquivalent: "h"
        )
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        hideOthers.target = NSApp
        appMenu.addItem(hideOthers)

        let showAll = NSMenuItem(
            title: "Show All",
            action: #selector(NSApplication.unhideAllApplications(_:)),
            keyEquivalent: ""
        )
        showAll.target = NSApp
        appMenu.addItem(showAll)
        appMenu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit Awqat", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        appMenu.addItem(quit)

        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu
        let undo = NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(undo)
        let redo = NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redo)
        editMenu.addItem(.separator())
        for (title, selector, key) in [
            ("Cut", "cut:", "x"),
            ("Copy", "copy:", "c"),
            ("Paste", "paste:", "v")
        ] {
            editMenu.addItem(NSMenuItem(title: title, action: Selector(selector), keyEquivalent: key))
        }
        editMenu.addItem(.separator())
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))

        let windowMenuItem = NSMenuItem()
        mainMenu.addItem(windowMenuItem)
        let windowMenu = NSMenu(title: "Window")
        windowMenuItem.submenu = windowMenu
        windowMenu.addItem(
            NSMenuItem(
                title: "Minimize",
                action: #selector(NSWindow.performMiniaturize(_:)),
                keyEquivalent: "m"
            )
        )
        windowMenu.addItem(
            NSMenuItem(
                title: "Bring All to Front",
                action: #selector(NSApplication.arrangeInFront(_:)),
                keyEquivalent: ""
            )
        )

        NSApp.mainMenu = mainMenu
    }
}
