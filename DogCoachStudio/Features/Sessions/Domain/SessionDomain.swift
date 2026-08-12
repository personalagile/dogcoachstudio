import Foundation

enum ExerciseOutcome: String, CaseIterable, Hashable, Sendable {
    case notStarted
    case strongSupport
    case lightSupport
    case independent
    case stableWithDistraction
}

enum ScheduledSessionKind: String, CaseIterable, Codable, Sendable { case individual, group }

enum ScheduledSessionStatus: String, CaseIterable, Codable, Sendable {
    case draft, scheduled, inProgress, completed, cancelled

    func canTransition(to next: Self) -> Bool {
        switch (self, next) {
        case (.draft, .scheduled), (.draft, .cancelled),
             (.scheduled, .inProgress), (.scheduled, .cancelled),
             (.inProgress, .completed), (.inProgress, .cancelled): true
        default: self == next
        }
    }
}

enum SessionBookingStatus: String, Codable, Sendable { case booked, cancelled }
enum SessionAttendanceStatus: String, CaseIterable, Codable, Sendable { case attended, excused, noShow, cancelled }
enum SessionPackagePolicy: String, Codable, Sendable { case redeem, skip, insufficientBalance }

struct ScheduledSessionDraft: Sendable {
    var title: String
    var startAt: Date
    var durationMinutes: Int
    var locationText: String?
    var kind: ScheduledSessionKind
    var templateVersionID: UUID?
    var dogIDs: [UUID]
    var labels: [String] = []
    var packageUnitsPerAttendee: Decimal = 1
}

struct ScheduledSessionSummary: Identifiable, Hashable, Sendable {
    let id: UUID
    let title: String
    let startAt: Date
    let durationMinutes: Int
    let kind: ScheduledSessionKind
    let status: ScheduledSessionStatus
    let templateVersionID: UUID?
    let bookingCount: Int
    let participantNames: [String]
    let isEvaluated: Bool
    let hasOverlap: Bool
    let labels: [String]
    let packageUnitsPerAttendee: Decimal
}

enum SessionCalendarScope: String, CaseIterable, Sendable {
    case day, week, month
}

enum SessionSchedulingError: Error, Equatable, Sendable {
    case invalidTitle
    case invalidDuration
    case dogNotFound(UUID)
    case templateVersionNotFound
    case sessionNotFound
    case invalidTransition(from: ScheduledSessionStatus, to: ScheduledSessionStatus)
    case duplicateBooking(UUID)
    case completedSessionImmutable
}

struct CompletionOutcomeOverride: Hashable, Sendable {
    let bookingID: UUID
    let exerciseVersionID: UUID
    let outcome: ExerciseOutcome
}

struct PersistentCompletionRequest: Hashable, Sendable {
    let sessionID: UUID
    let completionToken: UUID
    let attendanceByBookingID: [UUID: SessionAttendanceStatus]
    let defaultOutcome: ExerciseOutcome
    let overrides: [CompletionOutcomeOverride]
}

struct PackagePreview: Hashable, Sendable {
    let bookingID: UUID
    let packageID: UUID?
    let balanceBefore: Decimal?
    let policy: SessionPackagePolicy
}

struct CompletionPreview: Hashable, Sendable {
    let sessionID: UUID
    let attendeeCount: Int
    let exerciseCount: Int
    let resultCount: Int
    let reportCount: Int
    let packages: [PackagePreview]
    var hasInsufficientBalance: Bool { packages.contains { $0.policy == .insufficientBalance } }
}

struct PersistentCompletionResult: Hashable, Sendable {
    let completedSessionID: UUID
    let sessionID: UUID
    let completionToken: UUID
    let revision: Int
    let attendanceCount: Int
    let resultCount: Int
    let redemptionCount: Int
    let reportCount: Int
}

enum PersistentCompletionError: Error, Equatable, Sendable {
    case sessionNotFound
    case sessionNotReady
    case missingAttendance(UUID)
    case unknownBooking(UUID)
    case templateMissing
    case templateHasNoExercises
    case unknownOverride
    case tokenPayloadConflict
    case sessionAlreadyCompleted
    case originalCompletionNotFound
    case correctionReasonRequired
    case injectedFailure
}

enum CompletionFailurePoint: Sendable { case none, beforeSave }

enum SessionCorrectionChange: Hashable, Sendable {
    case attendance(bookingID: UUID, status: SessionAttendanceStatus)
    case outcome(bookingID: UUID, exerciseVersionID: UUID, outcome: ExerciseOutcome)
}

struct SessionCorrectionRequest: Sendable {
    let originalCompletedSessionID: UUID
    let completionToken: UUID
    let reason: String
    let changes: [SessionCorrectionChange]
}
