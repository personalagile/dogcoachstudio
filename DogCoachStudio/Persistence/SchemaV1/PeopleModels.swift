import Foundation
import SwiftData

@Model
final class ClientRecord {
    var id: UUID = UUID()
    var displayName: String = ""
    var email: String?
    var phone: String?
    var addressStreet: String?
    var addressPostalCode: String?
    var addressCity: String?
    var addressCountryCode: String?
    var privateNotes: String?
    var isArchived: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var dogRoles: [ClientDogRoleRecord]?

    init(id: UUID = UUID(), displayName: String, createdAt: Date = .now) {
        self.id = id
        self.displayName = displayName
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }
}

@Model
final class ClientDogRoleRecord {
    var id: UUID = UUID()
    var clientID: UUID = UUID()
    var dogID: UUID = UUID()
    var roleRawValue: String = "owner"
    var isPrimaryContact: Bool = false
    var client: ClientRecord?
    var dog: DogRecord?

    init(
        id: UUID = UUID(),
        clientID: UUID,
        dogID: UUID,
        roleRawValue: String = "owner",
        isPrimaryContact: Bool = false
    ) {
        self.id = id
        self.clientID = clientID
        self.dogID = dogID
        self.roleRawValue = roleRawValue
        self.isPrimaryContact = isPrimaryContact
    }
}

@Model
final class DogRecord {
    var id: UUID = UUID()
    var name: String = ""
    var photoAssetID: String?
    var birthDate: Date?
    var breedText: String?
    var sexRawValue: String?
    var safetyFlagRawValuesData: Data = Data()
    @Transient var safetyFlagRawValues: [String] {
        get { CodableAttribute.decode([String].self, from: safetyFlagRawValuesData) ?? [] }
        set { safetyFlagRawValuesData = CodableAttribute.encode(newValue) }
    }
    var safetyPrivateNote: String?
    var isArchived: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var clientRoles: [ClientDogRoleRecord]?
    var intakeRecords: [IntakeRecordEntity]?
    var trainingGoals: [TrainingGoalRecord]?
    var bookings: [BookingRecord]?
    var packages: [TrainingPackageRecord]?
    var reports: [ClientReportRecord]?

    init(id: UUID = UUID(), name: String, createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }
}

@Model
final class IntakeRecordEntity {
    var id: UUID = UUID()
    var dogID: UUID = UUID()
    var revision: Int = 1
    var occurredAt: Date = Date()
    var reason: String = ""
    var environment: String = ""
    var history: String = ""
    var knownTriggers: String = ""
    var previousTraining: String = ""
    var healthNotes: String = ""
    var desiredOutcome: String = ""
    var privateNotes: String?
    var dog: DogRecord?

    init(id: UUID = UUID(), dogID: UUID, revision: Int = 1, occurredAt: Date = .now) {
        self.id = id
        self.dogID = dogID
        self.revision = revision
        self.occurredAt = occurredAt
    }
}

@Model
final class TrainingGoalRecord {
    var id: UUID = UUID()
    var dogID: UUID = UUID()
    var title: String = ""
    var statusRawValue: String = "planned"
    var targetDescription: String = ""
    var startedAt: Date = Date()
    var completedAt: Date?
    var exerciseID: UUID?
    var dog: DogRecord?
    var exercise: ExerciseRecord?

    init(id: UUID = UUID(), dogID: UUID, title: String, startedAt: Date = .now) {
        self.id = id
        self.dogID = dogID
        self.title = title
        self.startedAt = startedAt
    }
}
