import Foundation
import Testing
@testable import DogCoachStudio

@Suite("Phase 14 local notification planning")
struct NotificationPlannerTests {
    @Test("Every notification category is independently configurable")
    func independentCategories() {
        let fixture = NotificationFixture()
        let sessionOnly = NotificationPlanner.plan(sessions: fixture.sessions, dogs: fixture.dogs, preferences: .init(sessionReminders: true, birthdayReminders: false, evaluationReminders: false), now: fixture.now, calendar: fixture.calendar)
        let birthdayOnly = NotificationPlanner.plan(sessions: fixture.sessions, dogs: fixture.dogs, preferences: .init(sessionReminders: false, birthdayReminders: true, evaluationReminders: false), now: fixture.now, calendar: fixture.calendar)
        let evaluationOnly = NotificationPlanner.plan(sessions: fixture.sessions, dogs: fixture.dogs, preferences: .init(sessionReminders: false, birthdayReminders: false, evaluationReminders: true), now: fixture.now, calendar: fixture.calendar)

        #expect(sessionOnly.map(\.kind) == [.session])
        #expect(birthdayOnly.map(\.kind) == [.birthday])
        #expect(evaluationOnly.map(\.kind) == [.evaluation])
    }

    @Test("Cancelled, evaluated, and past session reminders are excluded")
    func exclusions() {
        let fixture = NotificationFixture()
        let cancelled = ScheduledSessionSummary(id: UUID(), title: "Cancelled", startAt: fixture.now.addingTimeInterval(7_200), durationMinutes: 60, kind: .group, status: .cancelled, templateVersionID: nil, bookingCount: 0, participantNames: [], isEvaluated: false, hasOverlap: false, labels: [], packageUnitsPerAttendee: 1)
        let evaluated = ScheduledSessionSummary(id: UUID(), title: "Done", startAt: fixture.now.addingTimeInterval(-7_200), durationMinutes: 60, kind: .group, status: .completed, templateVersionID: nil, bookingCount: 1, participantNames: [], isEvaluated: true, hasOverlap: false, labels: [], packageUnitsPerAttendee: 1)
        let values = NotificationPlanner.plan(sessions: [cancelled, evaluated], dogs: [], preferences: .init(sessionReminders: true, birthdayReminders: false, evaluationReminders: true), now: fixture.now, calendar: fixture.calendar)
        #expect(values.isEmpty)
    }

    @Test("Notification bodies expose titles and names but never private notes")
    func privacy() {
        let fixture = NotificationFixture()
        let text = NotificationPlanner.plan(sessions: fixture.sessions, dogs: fixture.dogs, preferences: .init(sessionReminders: true, birthdayReminders: true, evaluationReminders: true), now: fixture.now, calendar: fixture.calendar).map { $0.title + $0.body }.joined()
        #expect(text.contains("Recall"))
        #expect(text.contains("Milo"))
        #expect(!text.contains("PRIVATE-CANARY"))
    }
}

private struct NotificationFixture {
    let calendar: Calendar
    let now: Date
    let sessions: [ScheduledSessionSummary]
    let dogs: [DogSummary]

    init() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        self.calendar = calendar
        now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 12, hour: 10))!
        sessions = [.init(id: UUID(), title: "Recall", startAt: now.addingTimeInterval(7_200), durationMinutes: 45, kind: .group, status: .scheduled, templateVersionID: nil, bookingCount: 1, participantNames: ["Milo"], isEvaluated: false, hasOverlap: false, labels: [], packageUnitsPerAttendee: 1)]
        dogs = [.init(id: UUID(), name: "Milo", photoAssetID: nil, birthDate: calendar.date(from: DateComponents(year: 2020, month: 8, day: 13)), breedText: nil, sexRawValue: nil, safetyFlagRawValues: [], safetyPrivateNote: "PRIVATE-CANARY", isArchived: false, roles: [])]
    }
}
