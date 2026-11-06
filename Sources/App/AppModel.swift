import AppKit

final class AppModel {
    private let store: SettingsStore
    private(set) var settings: AppSettings
    private(set) var day: PrayerDay?
    private(set) var next: NextPrayer?
    private(set) var errorMessage: String?

    var onUpdate: (() -> Void)?

    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []

    init(store: SettingsStore = SettingsStore()) {
        self.store = store
        self.settings = store.load()
        refresh(now: Date(), force: true, notify: false)
    }

    deinit {
        stop()
    }

    func start() {
        guard timer == nil else { return }

        let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        timer.tolerance = 8
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer

        let workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refresh(force: true)
        }

        let activeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refresh(force: true)
        }

        let dayObserver = NotificationCenter.default.addObserver(
            forName: .NSCalendarDayChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refresh(force: true)
        }

        observers = [workspaceObserver, activeObserver, dayObserver]
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        observers.removeAll()
    }

    func apply(_ newSettings: AppSettings) {
        settings = newSettings
        _ = store.save(settings)
        refresh(now: Date(), force: true)
    }

    func refresh(now: Date = Date(), force: Bool = false, notify: Bool = true) {
        var localSettings = settings

        if let location = localSettings.location {
            let currentKey = PrayerCalculator.dateKey(for: now, timeZone: location.timeZone)
            let before = localSettings.overrides
            localSettings.overrides.removeExpiredTodayOverrides(currentDateKey: currentKey)
            if before != localSettings.overrides {
                settings = localSettings
                _ = store.save(settings)
            }
        }

        guard let location = localSettings.location else {
            let changed = day != nil || next != nil || errorMessage != nil
            day = nil
            next = nil
            errorMessage = nil
            if changed && notify { onUpdate?() }
            return
        }

        let previousDate = day?.date
        let previousNext = next
        let previousError = errorMessage
        let previousManualScopes = day?.manualScopes

        switch PrayerCalculator.makeDay(for: now, settings: localSettings) {
        case .success(let calculated):
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = location.timeZone
            day = calculated
            next = calculated.nextPrayer(after: now, calendar: calendar)
            errorMessage = nil
        case .failure(let error):
            day = nil
            next = nil
            errorMessage = error.message
        }

        let changed = force
            || previousDate != day?.date
            || previousNext != next
            || previousError != errorMessage
            || previousManualScopes != day?.manualScopes

        if changed && notify {
            onUpdate?()
        }
    }
}
