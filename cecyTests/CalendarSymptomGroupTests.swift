import Foundation
import SwiftData
import SwiftUI
import Testing
import UIKit
@testable import cecy

@MainActor struct CalendarSymptomGroupTests {
    private enum Failure: Error { case disk }

    @Test func dayDeletionIsAtomicAndPreservesOtherRecordsAfterReopen() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("symptoms.store")
        let day = try LocalDay(key: 20260929)
        let yesterday = try day.adding(days: -1)
        var expected = TrackerSnapshot()
        try autoreleasepool {
            let repository = try SwiftDataPeriodRepository.local(url: url)
            _ = try repository.add([Period(start: day)], completingOnboarding: false, today: day, now: day.formattingDate)
            _ = try repository.saveSexualActivity(SexualActivityEntry(day: day, activities: [.other]),
                                                  editing: false, today: day, now: day.formattingDate)
            let saved = try repository.addSymptoms([
                SymptomEntry(day: day, kind: .cramps, value: 2, notes: "First note"),
                SymptomEntry(day: day, kind: .headache, value: 1, notes: "Second note"),
                SymptomEntry(day: yesterday, kind: .cramps, value: 3, notes: "Keep this note")
            ], today: day, now: day.formattingDate)
            var fail = true
            var saves = 0
            let failing = SwiftDataPeriodRepository(container: repository.container, save: { context in
                saves += 1
                if fail { throw Failure.disk }
                try context.save()
            })
            #expect(throws: Failure.self) { try failing.deleteSymptoms(on: day) }
            #expect(try failing.load() == saved)
            #expect(saves == 1)
            fail = false
            expected = saved
            expected.symptoms.removeAll { $0.day == day }
            #expect(try failing.deleteSymptoms(on: day) == expected)
            #expect(saves == 2)
            #expect(throws: TrackingError.missingRecord) { try failing.deleteSymptoms(on: day) }
            #expect(saves == 2)
        }
        #expect(try SwiftDataPeriodRepository.local(url: url).load() == expected)
    }

    @Test(arguments: [320.0, 600.0])
    func symptomGroupWrapsAtLargeText(width: Double) throws {
        let day = try LocalDay(key: 20260929)
        let session = TrackerSession.preview(withHistory: true)
        #expect(session.addSymptoms(SymptomKind.allCases.map { SymptomEntry(day: day, kind: $0) }) == nil)
        func height(_ size: DynamicTypeSize) -> CGFloat {
            let host = UIHostingController(rootView: CalendarSymptomGroup(session: session, day: day)
                .environment(\.dynamicTypeSize, size))
            let measured = host.sizeThatFits(in: CGSize(width: width, height: 30_000))
            #expect(measured.width <= width + 1)
            #expect(measured.height.isFinite && measured.height > 0)
            return measured.height
        }
        #expect(height(.accessibility5) > height(.large))
    }
}
