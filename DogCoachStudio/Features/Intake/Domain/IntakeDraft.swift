import Foundation

/// Information that may be reviewed for client-facing use by a trainer.
/// Nothing in this type is generated or interpreted as a diagnosis.
struct IntakeClientFacingFields: Equatable, Sendable {
    var reason: String
    var environment: String
    var history: String
    var knownTriggers: String
    var previousTraining: String
    var healthNotes: String
    var desiredOutcome: String

    init(
        reason: String = "",
        environment: String = "",
        history: String = "",
        knownTriggers: String = "",
        previousTraining: String = "",
        healthNotes: String = "",
        desiredOutcome: String = ""
    ) {
        self.reason = reason
        self.environment = environment
        self.history = history
        self.knownTriggers = knownTriggers
        self.previousTraining = previousTraining
        self.healthNotes = healthNotes
        self.desiredOutcome = desiredOutcome
    }
}
/// Trainer-only information. This type has no conversion to client-facing fields.
struct IntakePrivateFields: Equatable, Sendable {
    var trainerNotes: String

    init(trainerNotes: String = "") {
        self.trainerNotes = trainerNotes
    }
}

struct IntakeDraft: Identifiable, Equatable, Sendable {
    let id: UUID
    let dogID: UUID
    var revision: Int
    var occurredAt: Date
    var clientFacing: IntakeClientFacingFields
    var privateFields: IntakePrivateFields

    init(
        id: UUID = UUID(),
        dogID: UUID,
        revision: Int = 1,
        occurredAt: Date = .now,
        clientFacing: IntakeClientFacingFields = .init(),
        privateFields: IntakePrivateFields = .init()
    ) {
        self.id = id
        self.dogID = dogID
        self.revision = revision
        self.occurredAt = occurredAt
        self.clientFacing = clientFacing
        self.privateFields = privateFields
    }
}
