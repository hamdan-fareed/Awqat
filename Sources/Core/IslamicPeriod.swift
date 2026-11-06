import Foundation

enum IslamicPeriod: String, CaseIterable, Identifiable {
    case fajr
    case sunrise
    case ishraqDuha
    case zawal
    case dhuhr
    case asr
    case maghrib
    case isha
    case islamicMidnight
    case lastThird

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fajr: return "Fajr"
        case .sunrise: return "Sunrise"
        case .ishraqDuha: return "Ishraq / Duha"
        case .zawal: return "Zawal"
        case .dhuhr: return "Dhuhr"
        case .asr: return "Asr"
        case .maghrib: return "Maghrib"
        case .isha: return "Isha"
        case .islamicMidnight: return "Islamic midnight"
        case .lastThird: return "Last third begins"
        }
    }

    var salah: Salah? {
        switch self {
        case .fajr: return .fajr
        case .dhuhr: return .dhuhr
        case .asr: return .asr
        case .maghrib: return .maghrib
        case .isha: return .isha
        default: return nil
        }
    }

    var isSalah: Bool { salah != nil }

    var detail: String {
        switch self {
        case .fajr:
            return "The obligatory dawn prayer. It begins at the second dawn (al-fajr al-sadiq), when a white light spreads across the horizon, and ends at sunrise."
        case .sunrise:
            return "Shuruq. The sun begins to rise and the time for Fajr has ended. Sunrise is not itself a prayer time."
        case .ishraqDuha:
            return "The voluntary mid-morning period and prayer. It begins after the sun has risen about a spear's length, approximated here as 15 minutes after sunrise, and lasts until Zawal."
        case .zawal:
            return "The sun reaches its highest point at the meridian. This is the brief time when prayer is paused; Dhuhr begins as the sun declines."
        case .dhuhr:
            return "The obligatory midday prayer. It begins after the sun passes the meridian and lasts until the time of Asr."
        case .asr:
            return "The obligatory afternoon prayer. In the Hanbali madhhab it begins when an object's shadow equals its height, plus the noon shadow, and ends at sunset."
        case .maghrib:
            return "The obligatory sunset prayer. It begins when the sun has fully set and lasts until the red twilight disappears."
        case .isha:
            return "The obligatory night prayer. In the Hanbali madhhab it begins when the red twilight (al-shafaq al-ahmar) disappears. Its preferred time ends at Islamic midnight."
        case .islamicMidnight:
            return "The midpoint between Maghrib and the next Fajr. It is not necessarily 00:00 on the clock and marks the end of the preferred time for Isha."
        case .lastThird:
            return "The final third of the night, beginning two-thirds of the way from Maghrib to Fajr. It is the preferred time for qiyam and witr."
        }
    }
}

struct ScheduleEntry: Identifiable, Equatable {
    let period: IslamicPeriod
    let time: Date
    let dayOffset: Int

    var id: IslamicPeriod { period }
}
