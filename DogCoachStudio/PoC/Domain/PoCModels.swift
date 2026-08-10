import Foundation

struct Dog: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let trainerPrivateNote: String?
}

struct Exercise: Identifiable, Hashable, Sendable {
    let id: UUID
    let title: String
}

struct TrainingTemplate: Identifiable, Hashable, Sendable {
    let id: UUID
    let title: String
    let exerciseIDs: [Exercise.ID]
}

struct DemoPackage: Identifiable, Hashable, Sendable {
    let id: UUID
    let dogID: Dog.ID
    let initialUnits: Int
}

struct Booking: Identifiable, Hashable, Sendable {
    let id: UUID
    let dogID: Dog.ID
    let packageID: DemoPackage.ID
}

enum AttendanceStatus: Hashable, Sendable {
    case pending
    case attended
    case absent
}

enum ExerciseOutcome: String, CaseIterable, Hashable, Sendable {
    case notStarted
    case strongSupport
    case lightSupport
    case independent
    case stableWithDistraction
}

struct ExerciseOverride: Hashable, Sendable {
    let dogID: Dog.ID
    let exerciseID: Exercise.ID
    let outcome: ExerciseOutcome
}

struct SessionCompletionRequest: Hashable, Sendable {
    let sessionID: UUID
    let dogs: [Dog]
    let exercises: [Exercise]
    let template: TrainingTemplate
    let packages: [DemoPackage]
    let bookings: [Booking]
    let attendanceByBookingID: [Booking.ID: AttendanceStatus]
    let defaultOutcome: ExerciseOutcome
    let overrides: [ExerciseOverride]
}

struct ExerciseSnapshot: Hashable, Sendable {
    let exerciseID: Exercise.ID
    let title: String
}

struct DogExerciseResult: Identifiable, Hashable, Sendable {
    let id: UUID
    let dogID: Dog.ID
    let exercise: ExerciseSnapshot
    let outcome: ExerciseOutcome
}

struct SimulatedPackageRedemption: Identifiable, Hashable, Sendable {
    let id: UUID
    let bookingID: Booking.ID
    let packageID: DemoPackage.ID
    let unitDelta: Int
}

struct ReportResultLine: Hashable, Sendable {
    let exerciseTitle: String
    let outcome: ExerciseOutcome
}

struct ReportDraft: Identifiable, Hashable, Sendable {
    let id: UUID
    let dogID: Dog.ID
    let dogName: String
    let results: [ReportResultLine]
}

struct SessionCompletionResult: Hashable, Sendable {
    let sessionID: UUID
    let completionToken: UUID
    let exerciseResults: [DogExerciseResult]
    let packageRedemptions: [SimulatedPackageRedemption]
    let reportDrafts: [ReportDraft]
}

enum SessionCompletionError: Error, Equatable, Sendable {
    case tokenPayloadConflict
    case sessionAlreadyCompleted
    case invalidRequest(String)
}
