import Foundation

/// A civil Gregorian day. UTC is only an arithmetic/formatting convention.
nonisolated struct LocalDay: Hashable, Comparable, Sendable, Identifiable {
    let key: Int
    private let anchor: Date
    var id: Int { key }
    var year: Int { key / 10_000 }
    var month: Int { key / 100 % 100 }
    var day: Int { key % 100 }

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    init(year: Int, month: Int, day: Int) throws {
        guard (1...9999).contains(year), (1...12).contains(month), (1...31).contains(day),
              let date = Self.calendar.date(from: DateComponents(year: year, month: month, day: day)) else {
            throw TrackingError.invalidDay
        }
        let actual = Self.calendar.dateComponents([.year, .month, .day], from: date)
        guard actual.year == year, actual.month == month, actual.day == day else {
            throw TrackingError.invalidDay
        }
        key = year * 10_000 + month * 100 + day
        anchor = date
    }

    init(key: Int) throws {
        guard key > 0, key <= 99_991_231 else { throw TrackingError.invalidDay }
        try self.init(year: key / 10_000, month: key / 100 % 100, day: key % 100)
    }

    init(date: Date, timeZone: TimeZone) throws {
        var calendar = Self.calendar
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.era, .year, .month, .day], from: date)
        guard components.era == 1,
              let year = components.year, let month = components.month, let day = components.day else {
            throw TrackingError.invalidDay
        }
        try self.init(year: year, month: month, day: day)
    }

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.key < rhs.key }

    func days(until other: Self) -> Int {
        // Both anchors were validated by the same fixed Gregorian calendar.
        Self.calendar.dateComponents([.day], from: anchor, to: other.anchor).day!
    }

    func adding(days: Int) throws -> Self {
        guard let date = Self.calendar.date(byAdding: .day, value: days, to: anchor) else {
            throw TrackingError.invalidDay
        }
        return try Self(date: date, timeZone: Self.calendar.timeZone)
    }

    func adding(months: Int) throws -> Self {
        guard let date = Self.calendar.date(byAdding: .month, value: months, to: anchor) else {
            throw TrackingError.invalidDay
        }
        return try Self(date: date, timeZone: Self.calendar.timeZone)
    }

    var monthStart: Self { try! Self(year: year, month: month, day: 1) }
    var daysInMonth: Int { Self.calendar.range(of: .day, in: .month, for: anchor)!.count }
    var weekday: Int { Self.calendar.component(.weekday, from: anchor) }
    var formattingDate: Date { anchor }

    func pickerDate(in timeZone: TimeZone) throws -> Date {
        var calendar = Self.calendar
        calendar.timeZone = timeZone
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)),
              try Self(date: date, timeZone: timeZone) == self else { throw TrackingError.invalidDay }
        return date
    }
}

nonisolated enum TrackingError: Error, LocalizedError, Equatable, Sendable {
    case invalidDay, futureDate, reversedEnd, duplicateStart, overlap, invalidData, missingRecord, noteTooLong

    var errorDescription: String? {
        switch self {
        case .invalidDay: "Choose a valid calendar date."
        case .futureDate: "A recorded date is ahead of today. Check your device date and recorded history."
        case .reversedEnd: "The end date must be on or after the start date."
        case .duplicateStart: "A period already starts on this date. Review the existing entry."
        case .overlap: "These dates overlap another recorded period. Review the recorded dates."
        case .invalidData: "Some recorded data needs attention. It has not been changed."
        case .missingRecord: "This record could not be found. Reload your records and try again."
        case .noteTooLong: "Keep the note to 2,000 characters or fewer. Your text has not been shortened."
        }
    }
}
