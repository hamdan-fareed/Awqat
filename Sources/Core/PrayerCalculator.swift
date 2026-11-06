import Foundation

enum PrayerError: Error, Equatable {
    case missingLocation
    case unableToCalculate

    var message: String {
        switch self {
        case .missingLocation:
            return "Set a location to see prayer times."
        case .unableToCalculate:
            return "Unable to calculate times for these coordinates and date."
        }
    }
}

struct NextPrayer: Equatable {
    let salah: Salah
    let time: Date
    let isTomorrow: Bool
}

struct PrayerDay {
    let date: Date
    let location: LocationSettings
    let entries: [ScheduleEntry]
    let basePrayers: [Salah: Date]
    let effectivePrayers: [Salah: Date]
    let tomorrowFajr: Date?
    let nightAvailable: Bool
    let manualScopes: [Salah: SalahOverrideScope]
    let orderingWarnings: [String]

    func time(for salah: Salah) -> Date? {
        effectivePrayers[salah]
    }

    func nextPrayer(after now: Date, calendar: Calendar) -> NextPrayer? {
        let future = effectivePrayers
            .filter { $0.value > now }
            .sorted { $0.value < $1.value }

        if let first = future.first {
            return NextPrayer(salah: first.key, time: first.value, isTomorrow: false)
        }

        if let tomorrowFajr {
            let isTomorrow = calendar.startOfDay(for: tomorrowFajr) > calendar.startOfDay(for: date)
            return NextPrayer(salah: .fajr, time: tomorrowFajr, isTomorrow: isTomorrow)
        }

        return nil
    }
}

struct PrayerCalculator {
    static func makeDay(for now: Date, settings: AppSettings) -> Result<PrayerDay, PrayerError> {
        guard let location = settings.location else {
            return .failure(.missingLocation)
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = location.timeZone
        calendar.locale = Locale(identifier: "en_US_POSIX")

        let startOfDay = calendar.startOfDay(for: now)
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: startOfDay)
        let coordinates = Coordinates(latitude: location.latitude, longitude: location.longitude)
        let parameters = calculationParameters(for: settings.calculation, coordinates: coordinates)

        guard let base = PrayerTimes(
            coordinates: coordinates,
            date: dateComponents,
            calculationParameters: parameters
        ) else {
            return .failure(.unableToCalculate)
        }

        let currentDateKey = dateKey(for: startOfDay, calendar: calendar)
        let tomorrowDate = calendar.date(byAdding: .day, value: 1, to: startOfDay)
        let tomorrowDateKey = tomorrowDate.map { dateKey(for: $0, calendar: calendar) }

        var tomorrowBase: PrayerTimes?
        if let tomorrowDate {
            let tomorrowComponents = calendar.dateComponents([.year, .month, .day], from: tomorrowDate)
            tomorrowBase = PrayerTimes(
                coordinates: coordinates,
                date: tomorrowComponents,
                calculationParameters: parameters
            )
        }

        var effective: [Salah: Date] = [:]
        var manualScopes: [Salah: SalahOverrideScope] = [:]

        for salah in Salah.allCases {
            let baseTime = time(for: salah, in: base)
            if let override = settings.overrides[salah], override.isActive(on: currentDateKey) {
                effective[salah] = resolve(override, relativeTo: baseTime, calendar: calendar)
                manualScopes[salah] = override.scope
            } else {
                effective[salah] = baseTime
            }
        }

        var tomorrowFajr: Date?
        if let tomorrowBase, let tomorrowDateKey {
            if let override = settings.overrides[.fajr], override.isActive(on: tomorrowDateKey) {
                tomorrowFajr = resolve(override, relativeTo: tomorrowBase.fajr, calendar: calendar)
            } else {
                tomorrowFajr = tomorrowBase.fajr
            }
        }

        var midnight: Date?
        var lastThird: Date?

        let manualFajr = settings.overrides[.fajr]?.isActive(on: currentDateKey) == true
        let manualMaghrib = settings.overrides[.maghrib]?.isActive(on: currentDateKey) == true

        if !manualFajr && !manualMaghrib, let sunnah = SunnahTimes(from: base) {
            midnight = sunnah.middleOfTheNight
            lastThird = sunnah.lastThirdOfTheNight
        } else if let tomorrowFajr, let maghrib = effective[.maghrib] {
            let nightDuration = tomorrowFajr.timeIntervalSince(maghrib)
            if nightDuration > 0 {
                midnight = roundedToMinute(maghrib.addingTimeInterval(nightDuration / 2))
                lastThird = roundedToMinute(maghrib.addingTimeInterval(nightDuration * (2.0 / 3.0)))
            }
        }

        var entries: [ScheduleEntry] = []
        func append(_ period: IslamicPeriod, _ time: Date?) {
            guard let time else { return }
            let offset = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: startOfDay),
                to: calendar.startOfDay(for: time)
            ).day ?? 0
            entries.append(ScheduleEntry(period: period, time: time, dayOffset: offset))
        }

        append(.fajr, effective[.fajr])
        append(.sunrise, base.sunrise)
        append(.ishraqDuha, base.sunrise.addingTimeInterval(15 * 60))
        append(.zawal, base.dhuhr)
        append(.dhuhr, effective[.dhuhr])
        append(.asr, effective[.asr])
        append(.maghrib, effective[.maghrib])
        append(.isha, effective[.isha])
        append(.islamicMidnight, midnight)
        append(.lastThird, lastThird)

        var warnings: [String] = []
        if let fajr = effective[.fajr], fajr < startOfDay {
            warnings.append("Fajr is before the selected day.")
        }
        if let fajr = effective[.fajr], fajr >= base.sunrise {
            warnings.append("Fajr is at or after sunrise.")
        }
        if let dhuhr = effective[.dhuhr], dhuhr < base.dhuhr {
            warnings.append("Dhuhr is before Zawal.")
        }
        if let dhuhr = effective[.dhuhr], let asr = effective[.asr], dhuhr >= asr {
            warnings.append("Dhuhr is at or after Asr.")
        }
        if let asr = effective[.asr], let maghrib = effective[.maghrib], asr >= maghrib {
            warnings.append("Asr is at or after Maghrib.")
        }
        if let maghrib = effective[.maghrib], let isha = effective[.isha], maghrib >= isha {
            warnings.append("Maghrib is at or after Isha.")
        }
        if let isha = effective[.isha], let tomorrowFajr, isha >= tomorrowFajr {
            warnings.append("Isha is at or after the next Fajr.")
        }

        let basePrayers = Dictionary(uniqueKeysWithValues: Salah.allCases.map { ($0, time(for: $0, in: base)) })

        return .success(
            PrayerDay(
                date: startOfDay,
                location: location,
                entries: entries,
                basePrayers: basePrayers,
                effectivePrayers: effective,
                tomorrowFajr: tomorrowFajr,
                nightAvailable: midnight != nil && lastThird != nil,
                manualScopes: manualScopes,
                orderingWarnings: warnings
            )
        )
    }

    static func calculationParameters(
        for settings: CalculationSettings,
        coordinates: Coordinates
    ) -> CalculationParameters {
        var parameters = CalculationMethod.other.params
        parameters.fajrAngle = settings.fajrAngle
        parameters.madhab = .shafi
        parameters.highLatitudeRule = highLatitudeRule(for: settings.highLatitude, coordinates: coordinates)
        parameters.rounding = .nearest

        switch settings.ishaBasis {
        case .angle:
            parameters.ishaAngle = settings.ishaAngle
            parameters.ishaInterval = 0
        case .minutes:
            parameters.ishaAngle = 0
            parameters.ishaInterval = settings.ishaMinutes
        }

        return parameters
    }

    static func dateKey(for date: Date, timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return dateKey(for: date, calendar: calendar)
    }

    private static func dateKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    private static func highLatitudeRule(
        for option: HighLatitudeOption,
        coordinates: Coordinates
    ) -> HighLatitudeRule {
        switch option {
        case .automatic:
            return .recommended(for: coordinates)
        case .middleOfTheNight:
            return .middleOfTheNight
        case .seventhOfTheNight:
            return .seventhOfTheNight
        case .twilightAngle:
            return .twilightAngle
        }
    }

    private static func time(for salah: Salah, in prayerTimes: PrayerTimes) -> Date {
        switch salah {
        case .fajr: return prayerTimes.fajr
        case .dhuhr: return prayerTimes.dhuhr
        case .asr: return prayerTimes.asr
        case .maghrib: return prayerTimes.maghrib
        case .isha: return prayerTimes.isha
        }
    }

    private static func resolve(
        _ override: SalahOverride,
        relativeTo baseTime: Date,
        calendar: Calendar
    ) -> Date {
        let baseDay = calendar.startOfDay(for: baseTime)
        var candidates: [Date] = []

        for offset in -1...1 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: baseDay) else { continue }
            var components = DateComponents()
            components.hour = override.hour
            components.minute = override.minute

            let searchStart = day.addingTimeInterval(-1)
            if let candidate = calendar.nextDate(
                after: searchStart,
                matching: components,
                matchingPolicy: .nextTime,
                repeatedTimePolicy: .first,
                direction: .forward
            ) {
                candidates.append(candidate)
            }
        }

        return candidates.min {
            abs($0.timeIntervalSince(baseTime)) < abs($1.timeIntervalSince(baseTime))
        } ?? baseTime
    }

    private static func roundedToMinute(_ date: Date) -> Date {
        let rounded = (date.timeIntervalSinceReferenceDate / 60).rounded() * 60
        return Date(timeIntervalSinceReferenceDate: rounded)
    }
}
