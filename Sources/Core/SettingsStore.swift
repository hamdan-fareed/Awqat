import Foundation

final class SettingsStore {
    static let storageKey = "Awqat.settings.v1"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> AppSettings {
        guard
            let json = defaults.string(forKey: Self.storageKey),
            let data = json.data(using: .utf8),
            let decoded = try? JSONDecoder().decode(AppSettings.self, from: data)
        else {
            return .defaultValue
        }
        return decoded
    }

    @discardableResult
    func save(_ settings: AppSettings) -> Bool {
        do {
            let data = try JSONEncoder().encode(settings)
            defaults.set(String(decoding: data, as: UTF8.self), forKey: Self.storageKey)
            return true
        } catch {
            return false
        }
    }

    func clear() {
        defaults.removeObject(forKey: Self.storageKey)
    }
}

enum SettingsValidation {
    static func validate(_ settings: AppSettings) -> [String] {
        var errors: [String] = []

        if let location = settings.location {
            if location.label.count > 100 {
                errors.append("Location label must be 100 characters or fewer.")
            }
            if !location.latitude.isFinite || location.latitude < -90 || location.latitude > 90 {
                errors.append("Latitude must be between -90 and 90.")
            }
            if !location.longitude.isFinite || location.longitude < -180 || location.longitude > 180 {
                errors.append("Longitude must be between -180 and 180.")
            }
            if location.timeZoneID.isEmpty || TimeZone(identifier: location.timeZoneID) == nil {
                errors.append("Choose a valid time zone.")
            }
        }

        if !settings.calculation.fajrAngle.isFinite || !(10...25).contains(settings.calculation.fajrAngle) {
            errors.append("Fajr angle must be between 10° and 25°.")
        }

        switch settings.calculation.ishaBasis {
        case .angle:
            if !settings.calculation.ishaAngle.isFinite || !(10...25).contains(settings.calculation.ishaAngle) {
                errors.append("Isha angle must be between 10° and 25°.")
            }
        case .minutes:
            if !(30...180).contains(settings.calculation.ishaMinutes) {
                errors.append("Isha minutes must be between 30 and 180.")
            }
        }

        for salah in Salah.allCases {
            guard let override = settings.overrides[salah] else { continue }
            if !(0...23).contains(override.hour) || !(0...59).contains(override.minute) {
                errors.append("\(salah.displayName) has an invalid manual time.")
            }
            if override.scope == .today && (override.dateKey?.isEmpty ?? true) {
                errors.append("\(salah.displayName) is missing its manual date.")
            }
        }

        return errors
    }

    static func locationSummary(_ location: LocationSettings?) -> String {
        guard let location else { return "No location set" }
        let label = location.label.trimmingCharacters(in: .whitespacesAndNewlines)
        return label.isEmpty ? "My Location" : label
    }
}
