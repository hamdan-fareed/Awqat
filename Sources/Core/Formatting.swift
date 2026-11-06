import Foundation

enum TimeFormatting {
    static func timeString(_ date: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeZone = timeZone
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    static func menuTimeString(_ date: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate("jm")
        return formatter.string(from: date)
    }

    static func compactMenuTimeString(_ date: Date, timeZone: TimeZone) -> String {
        var value = menuTimeString(date, timeZone: timeZone)
        value = value.replacingOccurrences(of: "\u{202f}", with: " ")
        value = value.replacingOccurrences(of: " AM", with: "a")
        value = value.replacingOccurrences(of: " PM", with: "p")
        return value
    }

    static func dateString(_ date: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate("EEEEdMMMM")
        return formatter.string(from: date)
    }

    static func overrideTimeString(
        hour: Int,
        minute: Int,
        timeZone: TimeZone,
        referenceDate: Date = Date()
    ) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        var components = calendar.dateComponents([.year, .month, .day], from: referenceDate)
        components.hour = hour
        components.minute = minute
        components.second = 0
        guard let date = calendar.date(from: components) else {
            return String(format: "%02d:%02d", hour, minute)
        }
        return timeString(date, timeZone: timeZone)
    }

    static func parseTime(_ input: String) -> (hour: Int, minute: Int)? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        let formats = ["HH:mm", "H:mm", "h:mm a"]
        for format in formats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = format
            let candidate = format.contains("a") ? text.uppercased() : text
            if let date = formatter.date(from: candidate) {
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = TimeZone(secondsFromGMT: 0)!
                let components = calendar.dateComponents([.hour, .minute], from: date)
                if let hour = components.hour, let minute = components.minute {
                    return (hour, minute)
                }
            }
        }

        let localized = DateFormatter()
        localized.locale = .current
        localized.timeZone = .current
        localized.dateStyle = .none
        localized.timeStyle = .short
        if let date = localized.date(from: text) {
            let components = Calendar(identifier: .gregorian).dateComponents([.hour, .minute], from: date)
            if let hour = components.hour, let minute = components.minute {
                return (hour, minute)
            }
        }

        return nil
    }
}

enum MenuBarSummary {
    static func allFiveTitle(day: PrayerDay?, timeZone: TimeZone) -> String {
        guard let day else { return "Awqat" }
        return Salah.allCases.map { salah in
            guard let date = day.time(for: salah) else { return "\(salah.shortName) --:--" }
            return "\(salah.shortName) \(TimeFormatting.compactMenuTimeString(date, timeZone: timeZone))"
        }
        .joined(separator: "  ")
    }

    static func nextTitle(next: NextPrayer?, timeZone: TimeZone) -> String {
        guard let next else { return "Awqat" }
        return "\(next.salah.displayName) \(TimeFormatting.menuTimeString(next.time, timeZone: timeZone))"
    }
}
