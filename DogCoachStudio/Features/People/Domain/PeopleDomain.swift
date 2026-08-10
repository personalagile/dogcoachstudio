import Foundation

enum ClientDogRoleKind: String, CaseIterable, Sendable {
    case owner
    case handler
    case emergencyContact
    case other
}

struct ClientDraft: Equatable, Sendable {
    var displayName: String
    var email: String?
    var phone: String?
    var addressStreet: String?
    var addressPostalCode: String?
    var addressCity: String?
    var addressCountryCode: String?
    var privateNotes: String?
}

struct DogDraft: Equatable, Sendable {
    var name: String
    var photoAssetID: String?
    var birthDate: Date?
    var breedText: String?
    var sexRawValue: String?
    var safetyFlagRawValues: [String]
    var safetyPrivateNote: String?
}

enum PeopleDomainError: Error, Equatable, Sendable {
    case blankName
    case clientNotFound(UUID)
    case dogNotFound(UUID)
    case roleNotFound(UUID)
    case duplicateRole
    case primaryContactRequired
    case recordHasHistory
    case persistence(operation: String)
}

enum PeopleDomainValidator {
    static func validatedName(_ value: String) throws -> String {
        let name = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw PeopleDomainError.blankName }
        return name
    }

    static func validateUniqueRole(
        clientID: UUID,
        dogID: UUID,
        kind: ClientDogRoleKind,
        existingRoles: [ClientDogRoleRecord],
        excluding roleID: UUID? = nil
    ) throws {
        guard !existingRoles.contains(where: {
            $0.id != roleID && $0.clientID == clientID && $0.dogID == dogID && $0.roleRawValue == kind.rawValue
        }) else {
            throw PeopleDomainError.duplicateRole
        }
    }

    static func validatePrimaryContactInvariant(_ roles: [ClientDogRoleRecord]) throws {
        guard roles.isEmpty || roles.lazy.filter(\.isPrimaryContact).count == 1 else {
            throw PeopleDomainError.primaryContactRequired
        }
    }
}

@MainActor
protocol PeopleRepository: AnyObject {
    func clients(search: String?, includeArchived: Bool) throws -> [ClientRecord]
    func client(id: UUID) throws -> ClientRecord?
    func insert(_ client: ClientRecord) throws
    func save(_ client: ClientRecord) throws
    func delete(_ client: ClientRecord) throws

    func dogs(search: String?, includeArchived: Bool) throws -> [DogRecord]
    func dog(id: UUID) throws -> DogRecord?
    func insert(_ dog: DogRecord) throws
    func save(_ dog: DogRecord) throws
    func delete(_ dog: DogRecord) throws

    func roles(clientID: UUID?, dogID: UUID?) throws -> [ClientDogRoleRecord]
    func insert(_ role: ClientDogRoleRecord) throws
    func save(_ role: ClientDogRoleRecord) throws
    func delete(_ role: ClientDogRoleRecord) throws
    func saveChanges() throws
}
