import Foundation
import SwiftData

@MainActor
final class SwiftDataScheduledSessionRepository {
    private let context: ModelContext
    private let uuid: any UUIDGenerating

    init(context: ModelContext, uuid: any UUIDGenerating) {
        self.context = context
        self.uuid = uuid
    }

    func create(_ draft: ScheduledSessionDraft) throws -> UUID {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { throw SessionSchedulingError.invalidTitle }
        guard draft.durationMinutes > 0 else { throw SessionSchedulingError.invalidDuration }
        guard Set(draft.dogIDs).count == draft.dogIDs.count else {
            throw SessionSchedulingError.duplicateBooking(draft.dogIDs.first!)
        }
        let dogs = try context.fetch(FetchDescriptor<DogRecord>())
        for id in draft.dogIDs where !dogs.contains(where: { $0.id == id && !$0.isArchived }) {
            throw SessionSchedulingError.dogNotFound(id)
        }
        var template: TemplateVersionRecord?
        if let templateID = draft.templateVersionID {
            template = try context.fetch(FetchDescriptor<TemplateVersionRecord>()).first { $0.id == templateID }
            guard template != nil else { throw SessionSchedulingError.templateVersionNotFound }
        }

        let record = ScheduledSessionRecord(id: uuid.makeUUID(), title: title, startAt: draft.startAt, durationMinutes: draft.durationMinutes)
        record.locationText = draft.locationText
        record.kindRawValue = draft.kind.rawValue
        record.statusRawValue = ScheduledSessionStatus.draft.rawValue
        record.templateVersionID = draft.templateVersionID
        record.templateVersion = template
        context.insert(record)

        let packages = try context.fetch(FetchDescriptor<TrainingPackageRecord>())
        record.bookings = draft.dogIDs.map { dogID in
            let booking = BookingRecord(id: uuid.makeUUID(), sessionID: record.id, dogID: dogID)
            booking.session = record
            booking.dog = dogs.first { $0.id == dogID }
            booking.expectedPackage = packages.first { $0.dogID == dogID && !$0.isClosed }
            booking.expectedPackageID = booking.expectedPackage?.id
            context.insert(booking)
            return booking
        }
        try context.save()
        return record.id
    }

    func list() throws -> [ScheduledSessionSummary] {
        let sessions = try context.fetch(FetchDescriptor<ScheduledSessionRecord>())
        return sessions.map { record in
            let start = record.startAt
            let end = start.addingTimeInterval(TimeInterval(record.durationMinutes * 60))
            let overlaps = sessions.contains { other in
                guard other.id != record.id, other.statusRawValue != ScheduledSessionStatus.cancelled.rawValue else { return false }
                let otherEnd = other.startAt.addingTimeInterval(TimeInterval(other.durationMinutes * 60))
                return start < otherEnd && other.startAt < end
            }
            return ScheduledSessionSummary(
                id: record.id,
                title: record.title,
                startAt: record.startAt,
                durationMinutes: record.durationMinutes,
                kind: ScheduledSessionKind(rawValue: record.kindRawValue) ?? .group,
                status: ScheduledSessionStatus(rawValue: record.statusRawValue) ?? .draft,
                templateVersionID: record.templateVersionID,
                bookingCount: (record.bookings ?? []).filter { $0.bookingStatusRawValue == SessionBookingStatus.booked.rawValue }.count,
                hasOverlap: overlaps
            )
        }.sorted { $0.startAt < $1.startAt }
    }

    func transition(sessionID: UUID, to next: ScheduledSessionStatus) throws {
        guard let record = try find(sessionID) else { throw SessionSchedulingError.sessionNotFound }
        let current = ScheduledSessionStatus(rawValue: record.statusRawValue) ?? .draft
        guard current.canTransition(to: next) else { throw SessionSchedulingError.invalidTransition(from: current, to: next) }
        record.statusRawValue = next.rawValue
        try context.save()
    }

    func session(id: UUID) throws -> ScheduledSessionRecord? { try find(id) }

    private func find(_ id: UUID) throws -> ScheduledSessionRecord? {
        try context.fetch(FetchDescriptor<ScheduledSessionRecord>()).first { $0.id == id }
    }
}
