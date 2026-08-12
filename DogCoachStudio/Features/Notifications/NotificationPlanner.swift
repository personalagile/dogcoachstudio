import Foundation
import SwiftData

struct NotificationPreferences: Equatable, Sendable {
    var sessionReminders: Bool
    var birthdayReminders: Bool
    var evaluationReminders: Bool
    var sessionLeadMinutes: Int = 60

    static func stored(in defaults: UserDefaults = .standard) -> Self {
        .init(
            sessionReminders: defaults.bool(forKey: "notifications.sessions"),
            birthdayReminders: defaults.bool(forKey: "notifications.birthdays"),
            evaluationReminders: defaults.bool(forKey: "notifications.evaluations")
        )
    }
}

enum PlannedNotificationKind: String, Sendable { case session, birthday, evaluation }

struct PlannedNotification: Identifiable, Equatable, Sendable {
    let id: String
    let kind: PlannedNotificationKind
    let title: String
    let body: String
    let date: Date
}

enum NotificationPlanner {
    static func plan(
        sessions: [ScheduledSessionSummary],
        dogs: [DogSummary],
        preferences: NotificationPreferences,
        now: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> [PlannedNotification] {
        var output: [PlannedNotification] = []
        if preferences.sessionReminders {
            output += sessions.compactMap { session in
                let date = session.startAt.addingTimeInterval(TimeInterval(-preferences.sessionLeadMinutes * 60))
                guard date > now, session.status != .cancelled else { return nil }
                return PlannedNotification(
                    id: "dogcoach.session.\(session.id.uuidString)",
                    kind: .session,
                    title: String(localized: "Upcoming session"),
                    body: session.title,
                    date: date
                )
            }
        }
        if preferences.evaluationReminders {
            output += sessions.compactMap { session in
                let finished = session.startAt.addingTimeInterval(TimeInterval(session.durationMinutes * 60))
                let date = max(finished.addingTimeInterval(60 * 60), now.addingTimeInterval(60))
                guard !session.isEvaluated, session.status != .cancelled else { return nil }
                return PlannedNotification(
                    id: "dogcoach.evaluation.\(session.id.uuidString)",
                    kind: .evaluation,
                    title: String(localized: "Training still needs evaluation"),
                    body: session.title,
                    date: date
                )
            }
        }
        if preferences.birthdayReminders {
            output += dogs.compactMap { dog in
                guard let birthDate = dog.birthDate,
                      let next = nextBirthday(for: birthDate, after: now, calendar: calendar) else { return nil }
                return PlannedNotification(
                    id: "dogcoach.birthday.\(dog.id.uuidString)",
                    kind: .birthday,
                    title: String(localized: "Dog birthday"),
                    body: String(localized: "Today is \(dog.name)'s birthday."),
                    date: next
                )
            }
        }
        return output.sorted { $0.date < $1.date }
    }

    private static func nextBirthday(for birthDate: Date, after now: Date, calendar: Calendar) -> Date? {
        let birthday = calendar.dateComponents([.month, .day], from: birthDate)
        let year = calendar.component(.year, from: now)
        for candidateYear in year...(year + 1) {
            var components = DateComponents()
            components.year = candidateYear
            components.month = birthday.month
            components.day = birthday.day
            components.hour = 9
            if let value = calendar.date(from: components), value > now { return value }
        }
        return nil
    }
}
