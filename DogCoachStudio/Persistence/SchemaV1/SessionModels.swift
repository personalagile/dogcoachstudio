import Foundation
import SwiftData

@Model
final class ScheduledSessionRecord {
    var id: UUID = UUID()
    var title: String = ""
    var startAt: Date = Date()
    var durationMinutes: Int = 0
    var locationText: String?
    var kindRawValue: String = "group"
    var statusRawValue: String = "draft"
    var templateVersionID: UUID?
    var calendarEventIdentifier: String?
    var templateVersion: TemplateVersionRecord?
    var bookings: [BookingRecord]?
    var completedSession: CompletedSessionRecord?

    init(id: UUID = UUID(), title: String, startAt: Date, durationMinutes: Int) {
        self.id = id
        self.title = title
        self.startAt = startAt
        self.durationMinutes = durationMinutes
    }
}

@Model
final class BookingRecord {
    var id: UUID = UUID()
    var sessionID: UUID = UUID()
    var dogID: UUID = UUID()
    var bookingStatusRawValue: String = "booked"
    var expectedPackageID: UUID?
    var session: ScheduledSessionRecord?
    var dog: DogRecord?
    var expectedPackage: TrainingPackageRecord?
    var attendance: AttendanceRecord?

    init(id: UUID = UUID(), sessionID: UUID, dogID: UUID) {
        self.id = id
        self.sessionID = sessionID
        self.dogID = dogID
    }
}

@Model
final class AttendanceRecord {
    var id: UUID = UUID()
    var bookingID: UUID = UUID()
    var statusRawValue: String = "attended"
    var checkedAt: Date = Date()
    var packagePolicyRawValue: String = "redeem"
    var completionRevision: Int = 1
    var isActiveRevision: Bool = true
    var booking: BookingRecord?
    var results: [DogExerciseResultRecord]?
    var ledgerEntries: [PackageLedgerEntryRecord]?

    init(id: UUID = UUID(), bookingID: UUID, statusRawValue: String, checkedAt: Date = .now) {
        self.id = id
        self.bookingID = bookingID
        self.statusRawValue = statusRawValue
        self.checkedAt = checkedAt
    }
}

@Model
final class CompletedSessionRecord {
    var id: UUID = UUID()
    var sessionID: UUID = UUID()
    var completedAt: Date = Date()
    var completionToken: UUID = UUID()
    var revision: Int = 1
    var requestFingerprint: String = ""
    var supersedesCompletedSessionID: UUID?
    var correctionReason: String?
    var isActiveRevision: Bool = true
    var generalNotes: String?
    var defaultOutcomeRawValue: String = "independent"
    var session: ScheduledSessionRecord?
    var exerciseSnapshots: [ExerciseSnapshotRecord]?
    var reports: [ClientReportRecord]?

    init(
        id: UUID = UUID(),
        sessionID: UUID,
        completedAt: Date = .now,
        completionToken: UUID,
        revision: Int = 1
    ) {
        self.id = id
        self.sessionID = sessionID
        self.completedAt = completedAt
        self.completionToken = completionToken
        self.revision = revision
    }
}

@Model
final class ExerciseSnapshotRecord {
    var id: UUID = UUID()
    var completedSessionID: UUID = UUID()
    var sourceExerciseID: UUID = UUID()
    var sourceExerciseVersionID: UUID = UUID()
    var localeIdentifier: String = "en"
    var title: String = ""
    var goal: String = ""
    var setup: String = ""
    var stepsData: Data = Data()
    var successCriteriaData: Data = Data()
    @Transient var steps: [String] {
        get { CodableAttribute.decode([String].self, from: stepsData) ?? [] }
        set { stepsData = CodableAttribute.encode(newValue) }
    }
    @Transient var successCriteria: [String] {
        get { CodableAttribute.decode([String].self, from: successCriteriaData) ?? [] }
        set { successCriteriaData = CodableAttribute.encode(newValue) }
    }
    var homework: String = ""
    var safetyNotes: String = ""
    var completedSession: CompletedSessionRecord?
    var results: [DogExerciseResultRecord]?

    init(id: UUID = UUID(), completedSessionID: UUID, sourceExerciseID: UUID, sourceExerciseVersionID: UUID) {
        self.id = id
        self.completedSessionID = completedSessionID
        self.sourceExerciseID = sourceExerciseID
        self.sourceExerciseVersionID = sourceExerciseVersionID
    }
}

@Model
final class DogExerciseResultRecord {
    var id: UUID = UUID()
    var attendanceID: UUID = UUID()
    var exerciseSnapshotID: UUID = UUID()
    var goalID: UUID?
    var outcomeRawValue: String = "notStarted"
    var wasPerformed: Bool = true
    var trainerPrivateNote: String?
    var clientFacingNote: String?
    var attendance: AttendanceRecord?
    var exerciseSnapshot: ExerciseSnapshotRecord?
    var goal: TrainingGoalRecord?

    init(id: UUID = UUID(), attendanceID: UUID, exerciseSnapshotID: UUID) {
        self.id = id
        self.attendanceID = attendanceID
        self.exerciseSnapshotID = exerciseSnapshotID
    }
}

@Model
final class ClientReportRecord {
    var id: UUID = UUID()
    var dogID: UUID = UUID()
    var completedSessionID: UUID = UUID()
    var localeIdentifier: String = "en"
    var statusRawValue: String = "draft"
    var revision: Int = 1
    var supersedesReportID: UUID?
    var body: String = ""
    var generatedAt: Date = Date()
    var approvedAt: Date?
    var exportedAt: Date?
    var dog: DogRecord?
    var completedSession: CompletedSessionRecord?

    init(id: UUID = UUID(), dogID: UUID, completedSessionID: UUID, localeIdentifier: String) {
        self.id = id
        self.dogID = dogID
        self.completedSessionID = completedSessionID
        self.localeIdentifier = localeIdentifier
    }
}
