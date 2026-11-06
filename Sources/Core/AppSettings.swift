import Foundation

// MARK: - Salah

enum Salah: String, Codable, CaseIterable, Hashable, Identifiable {
    case fajr
    case dhuhr
    case asr
    case maghrib
    case isha

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fajr: return "Fajr"
        case .dhuhr: return "Dhuhr"
        case .asr: return "Asr"
        case .maghrib: return "Maghrib"
        case .isha: return "Isha"
        }
    }

    var shortName: String {
        switch self {
        case .fajr: return "F"
        case .dhuhr: return "D"
        case .asr: return "A"
        case .maghrib: return "M"
        case .isha: return "I"
        }
    }

    var adhanPrayer: Prayer {
        switch self {
        case .fajr: return .fajr
        case .dhuhr: return .dhuhr
        case .asr: return .asr
        case .maghrib: return .maghrib
        case .isha: return .isha
        }
    }

    var displayOrder: Int {
        switch self {
        case .fajr: return 0
        case .dhuhr: return 1
        case .asr: return 2
        case .maghrib: return 3
        case .isha: return 4
        }
    }
}

// MARK: - Manual salah times

enum SalahOverrideScope: String, Codable, CaseIterable {
    case today
    case daily

    var displayName: String {
        switch self {
        case .today: return "Today"
        case .daily: return "Daily"
        }
    }
}

struct SalahOverride: Codable, Equatable {
    var scope: SalahOverrideScope
    var hour: Int
    var minute: Int
    /// yyyy-MM-dd in the selected location's time zone. Required for `.today`.
    var dateKey: String?

    init(scope: SalahOverrideScope, hour: Int, minute: Int, dateKey: String? = nil) {
        self.scope = scope
        self.hour = hour
        self.minute = minute
        self.dateKey = dateKey
    }

    func isActive(on currentDateKey: String) -> Bool {
        switch scope {
        case .today:
            return dateKey == currentDateKey
        case .daily:
            return true
        }
    }
}

struct SalahOverrides: Codable, Equatable {
    var fajr: SalahOverride?
    var dhuhr: SalahOverride?
    var asr: SalahOverride?
    var maghrib: SalahOverride?
    var isha: SalahOverride?

    init(
        fajr: SalahOverride? = nil,
        dhuhr: SalahOverride? = nil,
        asr: SalahOverride? = nil,
        maghrib: SalahOverride? = nil,
        isha: SalahOverride? = nil
    ) {
        self.fajr = fajr
        self.dhuhr = dhuhr
        self.asr = asr
        self.maghrib = maghrib
        self.isha = isha
    }

    subscript(salah: Salah) -> SalahOverride? {
        get {
            switch salah {
            case .fajr: return fajr
            case .dhuhr: return dhuhr
            case .asr: return asr
            case .maghrib: return maghrib
            case .isha: return isha
            }
        }
        set {
            switch salah {
            case .fajr: fajr = newValue
            case .dhuhr: dhuhr = newValue
            case .asr: asr = newValue
            case .maghrib: maghrib = newValue
            case .isha: isha = newValue
            }
        }
    }

    var isEmpty: Bool {
        fajr == nil && dhuhr == nil && asr == nil && maghrib == nil && isha == nil
    }

    mutating func reset() {
        fajr = nil
        dhuhr = nil
        asr = nil
        maghrib = nil
        isha = nil
    }

    /// Removes Today overrides that no longer apply to the current location date.
    mutating func removeExpiredTodayOverrides(currentDateKey: String) {
        for salah in Salah.allCases {
            if let override = self[salah],
               override.scope == .today,
               override.dateKey != currentDateKey {
                self[salah] = nil
            }
        }
    }
}

// MARK: - Location

struct LocationSettings: Codable, Equatable {
    var label: String
    var latitude: Double
    var longitude: Double
    var timeZoneID: String

    init(label: String = "My Location", latitude: Double, longitude: Double, timeZoneID: String) {
        self.label = label
        self.latitude = latitude
        self.longitude = longitude
        self.timeZoneID = timeZoneID
    }

    var timeZone: TimeZone {
        TimeZone(identifier: timeZoneID) ?? .current
    }

    var coordinateText: String {
        String(format: "%.4f, %.4f", latitude, longitude)
    }
}

// MARK: - Calculation

enum CalculationPreset: String, Codable, CaseIterable {
    case hanbali
    case ummAlQura
    case custom

    var displayName: String {
        switch self {
        case .hanbali: return "Hanbali"
        case .ummAlQura: return "Umm al-Qura"
        case .custom: return "Custom"
        }
    }
}

enum IshaBasis: String, Codable, CaseIterable {
    case angle
    case minutes

    var displayName: String {
        switch self {
        case .angle: return "Angle"
        case .minutes: return "Minutes"
        }
    }
}

enum HighLatitudeOption: String, Codable, CaseIterable {
    case automatic
    case middleOfTheNight
    case seventhOfTheNight
    case twilightAngle

    var displayName: String {
        switch self {
        case .automatic: return "Automatic"
        case .middleOfTheNight: return "Middle of night"
        case .seventhOfTheNight: return "Last seventh"
        case .twilightAngle: return "Twilight angle"
        }
    }
}

struct CalculationSettings: Codable, Equatable {
    var preset: CalculationPreset
    var fajrAngle: Double
    var ishaBasis: IshaBasis
    var ishaAngle: Double
    var ishaMinutes: Int
    var highLatitude: HighLatitudeOption

    static let hanbaliDefault = CalculationSettings(
        preset: .hanbali,
        fajrAngle: 18.0,
        ishaBasis: .angle,
        ishaAngle: 17.0,
        ishaMinutes: 90,
        highLatitude: .automatic
    )

    static let ummAlQura = CalculationSettings(
        preset: .ummAlQura,
        fajrAngle: 18.5,
        ishaBasis: .minutes,
        ishaAngle: 17.0,
        ishaMinutes: 90,
        highLatitude: .automatic
    )

    mutating func applyPreset(_ preset: CalculationPreset) {
        switch preset {
        case .hanbali:
            self = .hanbaliDefault
        case .ummAlQura:
            self = .ummAlQura
        case .custom:
            self.preset = .custom
        }
    }
}

// MARK: - Menu bar

enum MenuBarTitleMode: String, Codable, CaseIterable {
    case allFive
    case nextPrayer

    var displayName: String {
        switch self {
        case .allFive: return "All five"
        case .nextPrayer: return "Next prayer"
        }
    }
}

struct MenuBarSettings: Codable, Equatable {
    var isEnabled: Bool
    var titleMode: MenuBarTitleMode

    static let defaultValue = MenuBarSettings(isEnabled: false, titleMode: .allFive)
}

// MARK: - App settings

struct AppSettings: Codable, Equatable {
    var schemaVersion: Int
    var location: LocationSettings?
    var calculation: CalculationSettings
    var overrides: SalahOverrides
    var menuBar: MenuBarSettings

    init(
        schemaVersion: Int = 1,
        location: LocationSettings? = nil,
        calculation: CalculationSettings = .hanbaliDefault,
        overrides: SalahOverrides = SalahOverrides(),
        menuBar: MenuBarSettings = .defaultValue
    ) {
        self.schemaVersion = schemaVersion
        self.location = location
        self.calculation = calculation
        self.overrides = overrides
        self.menuBar = menuBar
    }

    static let defaultValue = AppSettings()
}
