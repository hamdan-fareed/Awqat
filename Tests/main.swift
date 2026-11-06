import Foundation

private var failures = 0

private func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    if condition() {
        print("PASS  \(message)")
    } else {
        failures += 1
        print("FAIL  \(message)")
    }
}

private func calendar(_ timeZone: TimeZone) -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    calendar.locale = Locale(identifier: "en_US_POSIX")
    return calendar
}

private func date(
    _ year: Int,
    _ month: Int,
    _ day: Int,
    _ hour: Int = 12,
    _ minute: Int = 0,
    timeZone: TimeZone
) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    components.hour = hour
    components.minute = minute
    return calendar(timeZone).date(from: components)!
}

private func components(_ date: Date, timeZone: TimeZone) -> DateComponents {
    calendar(timeZone).dateComponents([.year, .month, .day, .hour, .minute], from: date)
}

private func nearMinute(_ date: Date, hour: Int, minute: Int, timeZone: TimeZone) -> Bool {
    let value = components(date, timeZone: timeZone)
    return value.hour == hour && value.minute == minute
}

private func entry(_ period: IslamicPeriod, in day: PrayerDay) -> ScheduleEntry? {
    day.entries.first { $0.period == period }
}

private let riyadh = TimeZone(identifier: "Asia/Riyadh")!
private let london = TimeZone(identifier: "Europe/London")!
private let makkah = LocationSettings(
    label: "Makkah",
    latitude: 21.427009,
    longitude: 39.828685,
    timeZoneID: "Asia/Riyadh"
)

// 1. Umm al-Qura integration against Adhan's own fixture.
do {
    var settings = AppSettings.defaultValue
    settings.location = makkah
    settings.calculation = .ummAlQura
    let day = try! PrayerCalculator.makeDay(
        for: date(2016, 1, 5, timeZone: riyadh),
        settings: settings
    ).get()
    check(nearMinute(day.time(for: .fajr)!, hour: 5, minute: 38, timeZone: riyadh), "Umm al-Qura Fajr matches fixture")
    check(nearMinute(day.time(for: .dhuhr)!, hour: 12, minute: 26, timeZone: riyadh), "Umm al-Qura Dhuhr matches fixture")
    check(nearMinute(day.time(for: .asr)!, hour: 15, minute: 31, timeZone: riyadh), "Umm al-Qura Asr matches fixture")
    check(nearMinute(day.time(for: .isha)!, hour: 19, minute: 22, timeZone: riyadh), "Umm al-Qura Isha matches fixture")
}

// 2. Hanbali Asr is earlier than Hanafi Asr.
do {
    var settings = AppSettings.defaultValue
    settings.location = makkah
    let hanbali = try! PrayerCalculator.makeDay(
        for: date(2026, 6, 1, timeZone: riyadh),
        settings: settings
    ).get()
    var hanafiSettings = settings
    let coordinates = Coordinates(latitude: makkah.latitude, longitude: makkah.longitude)
    var hanafiParams = PrayerCalculator.calculationParameters(for: settings.calculation, coordinates: coordinates)
    hanafiParams.madhab = .hanafi
    let components = calendar(riyadh).dateComponents([.year, .month, .day], from: date(2026, 6, 1, timeZone: riyadh))
    let hanafi = PrayerTimes(coordinates: coordinates, date: components, calculationParameters: hanafiParams)!
    check(hanbali.time(for: .asr)! < hanafi.asr, "Hanbali Asr uses shadow factor 1 and is earlier than Hanafi")
    _ = hanafiSettings
    hanafiSettings.calculation = .hanbaliDefault
}

// 3. Today override applies only on its date.
do {
    var settings = AppSettings.defaultValue
    settings.location = makkah
    let today = date(2026, 6, 1, timeZone: riyadh)
    let todayKey = PrayerCalculator.dateKey(for: today, timeZone: riyadh)
    let base = try! PrayerCalculator.makeDay(for: today, settings: settings).get()
    settings.overrides[.fajr] = SalahOverride(scope: .today, hour: 4, minute: 55, dateKey: todayKey)
    let overridden = try! PrayerCalculator.makeDay(for: today, settings: settings).get()
    check(nearMinute(overridden.time(for: .fajr)!, hour: 4, minute: 55, timeZone: riyadh), "Today override changes Fajr")
    check(overridden.manualScopes[.fajr] == .today, "Today override is marked manual")

    let tomorrow = date(2026, 6, 2, timeZone: riyadh)
    let nextDay = try! PrayerCalculator.makeDay(for: tomorrow, settings: settings).get()
    check(nextDay.manualScopes[.fajr] == nil, "Today override expires the next day")
    check(!nearMinute(nextDay.time(for: .fajr)!, hour: 4, minute: 55, timeZone: riyadh), "Expired Today override does not affect next day")
    _ = base
}

// 4. Daily override repeats.
do {
    var settings = AppSettings.defaultValue
    settings.location = makkah
    settings.overrides[.dhuhr] = SalahOverride(scope: .daily, hour: 12, minute: 45)
    let day1 = try! PrayerCalculator.makeDay(for: date(2026, 6, 1, timeZone: riyadh), settings: settings).get()
    let day2 = try! PrayerCalculator.makeDay(for: date(2026, 6, 2, timeZone: riyadh), settings: settings).get()
    check(nearMinute(day1.time(for: .dhuhr)!, hour: 12, minute: 45, timeZone: riyadh), "Daily override applies today")
    check(nearMinute(day2.time(for: .dhuhr)!, hour: 12, minute: 45, timeZone: riyadh), "Daily override applies tomorrow")
}

// 5. Isha after midnight resolves to the next local date.
do {
    var settings = AppSettings.defaultValue
    settings.location = makkah
    settings.overrides[.isha] = SalahOverride(scope: .daily, hour: 0, minute: 30)
    let day = try! PrayerCalculator.makeDay(for: date(2026, 6, 1, timeZone: riyadh), settings: settings).get()
    let isha = day.time(for: .isha)!
    let ishaComponents = components(isha, timeZone: riyadh)
    check(ishaComponents.hour == 0 && ishaComponents.minute == 30, "After-midnight Isha keeps 00:30 clock time")
    check(isha > day.time(for: .maghrib)!, "After-midnight Isha is after Maghrib")
    check(entry(.isha, in: day)?.dayOffset == 1, "After-midnight Isha is marked tomorrow")
}

// 6. Night markers follow a manual Maghrib.
do {
    var settings = AppSettings.defaultValue
    settings.location = makkah
    let today = date(2026, 6, 1, timeZone: riyadh)
    let initial = try! PrayerCalculator.makeDay(for: today, settings: settings).get()
    let initialLastThird = entry(.lastThird, in: initial)!.time
    let initialMaghrib = initial.time(for: .maghrib)!
    let manualMaghrib = initialMaghrib.addingTimeInterval(10 * 60)
    let maghribComponents = components(manualMaghrib, timeZone: riyadh)
    settings.overrides[.maghrib] = SalahOverride(
        scope: .daily,
        hour: maghribComponents.hour!,
        minute: maghribComponents.minute!
    )
    let adjusted = try! PrayerCalculator.makeDay(for: today, settings: settings).get()
    let adjustedLastThird = entry(.lastThird, in: adjusted)!.time
    check(adjustedLastThird > initialLastThird, "Last third follows a manual Maghrib")
}

// 7. Dhuhr override does not move Zawal.
do {
    var settings = AppSettings.defaultValue
    settings.location = makkah
    let today = date(2026, 6, 1, timeZone: riyadh)
    let initial = try! PrayerCalculator.makeDay(for: today, settings: settings).get()
    let initialZawal = entry(.zawal, in: initial)!.time
    let dhuhr = initial.time(for: .dhuhr)!
    let shifted = dhuhr.addingTimeInterval(15 * 60)
    let shiftedComponents = components(shifted, timeZone: riyadh)
    settings.overrides[.dhuhr] = SalahOverride(
        scope: .daily,
        hour: shiftedComponents.hour!,
        minute: shiftedComponents.minute!
    )
    let adjusted = try! PrayerCalculator.makeDay(for: today, settings: settings).get()
    check(entry(.zawal, in: adjusted)!.time == initialZawal, "Dhuhr override does not move Zawal")
    check(adjusted.time(for: .dhuhr)! != initial.time(for: .dhuhr)!, "Dhuhr override changes Dhuhr")
}

// 8. Next prayer rolls to tomorrow Fajr after Isha.
do {
    var settings = AppSettings.defaultValue
    settings.location = makkah
    let today = date(2026, 6, 1, timeZone: riyadh)
    let day = try! PrayerCalculator.makeDay(for: today, settings: settings).get()
    let afterIsha = day.time(for: .isha)!.addingTimeInterval(60)
    let next = day.nextPrayer(after: afterIsha, calendar: calendar(riyadh))
    check(next?.salah == .fajr, "Next prayer after Isha is Fajr")
    check(next?.isTomorrow == true, "Next Fajr is marked tomorrow")
}

// 9. Settings round-trip and validation.
do {
    var settings = AppSettings.defaultValue
    settings.location = makkah
    settings.overrides[.asr] = SalahOverride(scope: .daily, hour: 15, minute: 45)
    settings.menuBar.isEnabled = true
    let data = try! JSONEncoder().encode(settings)
    let decoded = try! JSONDecoder().decode(AppSettings.self, from: data)
    check(decoded == settings, "AppSettings Codable round-trip")
    check(SettingsValidation.validate(settings).isEmpty, "Valid settings have no errors")

    var invalid = settings
    invalid.location?.latitude = 100
    check(!SettingsValidation.validate(invalid).isEmpty, "Invalid latitude is rejected")
}

// 10. Time parsing.
do {
    check(TimeFormatting.parseTime("17:12")?.hour == 17, "24-hour parser works")
    check(TimeFormatting.parseTime("5:12 PM")?.hour == 17, "12-hour parser works")
    check(TimeFormatting.parseTime("5:12 pm")?.hour == 17, "Lowercase 12-hour parser works")
    check(TimeFormatting.parseTime("not a time") == nil, "Invalid time is rejected")
}

// 11. High-latitude / polar result does not crash.
do {
    var settings = AppSettings.defaultValue
    settings.location = LocationSettings(
        label: "Tromso",
        latitude: 69.6492,
        longitude: 18.9553,
        timeZoneID: "Europe/Oslo"
    )
    let result = PrayerCalculator.makeDay(
        for: date(2026, 6, 21, timeZone: TimeZone(identifier: "Europe/Oslo")!),
        settings: settings
    )
    switch result {
    case .success:
        check(true, "Polar case returned a calculated day")
    case .failure(.unableToCalculate):
        check(true, "Polar case returned a clean calculation error")
    case .failure(.missingLocation):
        check(false, "Polar case unexpectedly reported a missing location")
    }
}

// 12. Manual ordering warning.
do {
    var settings = AppSettings.defaultValue
    settings.location = makkah
    settings.overrides[.fajr] = SalahOverride(scope: .daily, hour: 23, minute: 0)
    let day = try! PrayerCalculator.makeDay(for: date(2026, 6, 1, timeZone: riyadh), settings: settings).get()
    check(!day.orderingWarnings.isEmpty, "Invalid manual order produces a warning")
}

// 13. London DST sanity.
do {
    var settings = AppSettings.defaultValue
    settings.location = LocationSettings(
        label: "London",
        latitude: 51.5072,
        longitude: -0.1276,
        timeZoneID: "Europe/London"
    )
    let winter = try! PrayerCalculator.makeDay(for: date(2026, 1, 15, timeZone: london), settings: settings).get()
    let summer = try! PrayerCalculator.makeDay(for: date(2026, 7, 15, timeZone: london), settings: settings).get()
    check(winter.time(for: .fajr)! != summer.time(for: .fajr)!, "London winter and summer Fajr differ")
    check(entry(.lastThird, in: winter) != nil, "London winter has a last third")
}

print("")
if failures == 0 {
    print("All checks passed.")
    exit(0)
} else {
    print("\(failures) check(s) failed.")
    exit(1)
}
