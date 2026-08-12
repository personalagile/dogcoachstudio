import Foundation
import SwiftData
@preconcurrency import UserNotifications

@MainActor
struct LocalNotificationService {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) { self.center = center }

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .badge, .sound])
    }

    func reschedule(context: ModelContext, preferences: NotificationPreferences, now: Date) async throws {
        let prefix = "dogcoach."
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(prefix) })
        guard preferences.sessionReminders || preferences.birthdayReminders || preferences.evaluationReminders else { return }

        let sessions = try SwiftDataScheduledSessionRepository(context: context, uuid: SystemUUIDGenerator()).list()
        let dogs = try context.fetch(FetchDescriptor<DogRecord>()).filter { !$0.isArchived }.map { record in
            DogSummary(id: record.id, name: record.name, photoAssetID: record.photoAssetID, birthDate: record.birthDate, breedText: record.breedText, sexRawValue: record.sexRawValue, safetyFlagRawValues: record.safetyFlagRawValues, safetyPrivateNote: record.safetyPrivateNote, isArchived: record.isArchived, roles: [])
        }
        for item in NotificationPlanner.plan(sessions: sessions, dogs: dogs, preferences: preferences, now: now) {
            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = item.body
            content.sound = .default
            let interval = max(item.date.timeIntervalSince(now), 1)
            try await center.add(UNNotificationRequest(identifier: item.id, content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)))
        }
    }
}
