import Foundation
import Observation
import SwiftData

struct ClientSummary: Identifiable, Hashable, Sendable {
    let id: UUID
    let displayName: String
    let email: String?
    let phone: String?
    let addressStreet: String?
    let addressPostalCode: String?
    let addressCity: String?
    let addressCountryCode: String?
    let privateNotes: String?
    let isArchived: Bool
}

struct DogRoleSummary: Identifiable, Hashable, Sendable {
    let id: UUID
    let clientID: UUID
    let clientName: String
    let kind: ClientDogRoleKind
    let isPrimaryContact: Bool
}

struct DogSummary: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let photoAssetID: String?
    let birthDate: Date?
    let breedText: String?
    let sexRawValue: String?
    let safetyFlagRawValues: [String]
    let safetyPrivateNote: String?
    let isArchived: Bool
    let roles: [DogRoleSummary]

    var primaryOwnerName: String? {
        roles.first(where: { $0.isPrimaryContact })?.clientName ?? roles.first?.clientName
    }
}

struct DogTrainingSummary: Identifiable, Hashable, Sendable {
    let id: UUID
    let title: String
    let completedAt: Date
    let outcome: String
}

enum PeopleSelection: Hashable {
    case client(UUID)
    case dog(UUID)
}

@MainActor
@Observable
final class PeopleFeatureModel {
    private let context: ModelContext
    private let people: PeopleUseCases
    let intakeRepository: any IntakeRepository
    let goalRepository: any TrainingGoalRepository
    private let packageRepository: PackageLedgerRepository
    let clock: any AppClock
    let uuidGenerator: any UUIDGenerating

    var clients: [ClientSummary] = []
    var dogs: [DogSummary] = []
    var searchText = ""
    var includeArchived = false
    var selection: PeopleSelection?
    var error: AppError?
    private(set) var contentRevision = 0

    init(
        context: ModelContext,
        clock: any AppClock,
        uuidGenerator: any UUIDGenerating
    ) {
        self.context = context
        people = PeopleUseCases(
            repository: SwiftDataPeopleRepository(context: context),
            clock: clock,
            uuidGenerator: uuidGenerator
        )
        intakeRepository = SwiftDataIntakeRepository(context: context)
        goalRepository = SwiftDataTrainingGoalRepository(context: context)
        packageRepository = PackageLedgerRepository(context: context, uuid: uuidGenerator, clock: clock)
        self.clock = clock
        self.uuidGenerator = uuidGenerator
        reload()
    }

    var selectedClient: ClientSummary? {
        guard case .client(let id) = selection else { return nil }
        return clients.first(where: { $0.id == id })
    }

    var selectedDog: DogSummary? {
        guard case .dog(let id) = selection else { return nil }
        return dogs.first(where: { $0.id == id })
    }

    func reload() {
        do {
            clients = try people.searchClients(searchText, includeArchived: includeArchived).map(Self.clientSummary)
            dogs = try people.searchDogs(searchText, includeArchived: includeArchived).map(Self.dogSummary)
            error = nil
        } catch {
            self.error = AppErrorMapper.map(error, operation: "people.reload")
        }
    }

    func createClient(_ draft: ClientDraft) throws {
        let client = try people.createClient(draft)
        reload()
        selection = .client(client.id)
    }

    func editClient(id: UUID, draft: ClientDraft) throws {
        _ = try people.editClient(id: id, draft: draft)
        reload()
    }

    func setClientArchived(id: UUID, archived: Bool) throws {
        _ = try people.setClientArchived(id: id, archived: archived)
        reload()
        if !includeArchived && archived { selection = nil }
    }

    func createDog(_ draft: DogDraft) throws {
        let dog = try people.createDog(draft)
        reload()
        selection = .dog(dog.id)
    }

    func editDog(id: UUID, draft: DogDraft) throws {
        _ = try people.editDog(id: id, draft: draft)
        reload()
    }

    func setDogArchived(id: UUID, archived: Bool) throws {
        _ = try people.setDogArchived(id: id, archived: archived)
        reload()
        if !includeArchived && archived { selection = nil }
    }

    func assignRole(clientID: UUID, dogID: UUID, kind: ClientDogRoleKind, primary: Bool) throws {
        try people.assignRole(clientID: clientID, dogID: dogID, kind: kind, isPrimaryContact: primary)
        reload()
    }

    func setPrimary(roleID: UUID, dogID: UUID) throws {
        try people.setPrimaryContact(roleID: roleID, dogID: dogID)
        reload()
    }

    func removeRole(id: UUID) throws {
        try people.removeRole(id: id)
        reload()
    }

    func goals(dogID: UUID) -> [TrainingGoal] {
        (try? goalRepository.goals(for: dogID)) ?? []
    }

    func saveGoal(_ goal: TrainingGoal) throws {
        try goalRepository.save(goal)
        contentRevision += 1
    }

    func deleteGoal(id: UUID) throws {
        try goalRepository.delete(id: id)
        contentRevision += 1
    }

    func advanceGoal(_ goal: TrainingGoal) throws {
        let statuses = TrainingGoalStatus.allCases
        guard let index = statuses.firstIndex(of: goal.status), index < statuses.index(before: statuses.endIndex) else { return }
        var updated = goal
        updated.transition(to: statuses[statuses.index(after: index)], at: clock.now())
        try saveGoal(updated)
    }

    func refreshDetailContent() { contentRevision += 1 }

    @discardableResult
    func perform(_ action: () throws -> Void, operation: String) -> Bool {
        do {
            try action()
            error = nil
            return true
        } catch {
            self.error = AppErrorMapper.map(error, operation: operation)
            return false
        }
    }

    func intakeDrafts(dogID: UUID) -> [IntakeDraft] {
        (try? intakeRepository.drafts(for: dogID)) ?? []
    }

    func packages(clientID: UUID) -> [TrainingPackageSummary] {
        let dogIDs = Set(dogs.filter { dog in dog.roles.contains { $0.clientID == clientID } }.map(\.id))
        return ((try? packageRepository.summaries()) ?? []).filter { dogIDs.contains($0.dogID) }
    }

    func completedTrainings(dogID: UUID) -> [DogTrainingSummary] {
        do {
            let bookings = try context.fetch(FetchDescriptor<BookingRecord>()).filter { $0.dogID == dogID }
            let sessionIDs = Set(bookings.map(\.sessionID))
            return try context.fetch(FetchDescriptor<CompletedSessionRecord>())
                .filter { $0.isActiveRevision && sessionIDs.contains($0.sessionID) }
                .compactMap { completion in
                    guard let session = completion.session ?? (try? context.fetch(FetchDescriptor<ScheduledSessionRecord>()).first { $0.id == completion.sessionID }) else { return nil }
                    return DogTrainingSummary(id: completion.id, title: session.title, completedAt: completion.completedAt, outcome: completion.defaultOutcomeRawValue)
                }
                .sorted { $0.completedAt > $1.completedAt }
        } catch { return [] }
    }

    private static func clientSummary(_ client: ClientRecord) -> ClientSummary {
        ClientSummary(
            id: client.id,
            displayName: client.displayName,
            email: client.email,
            phone: client.phone,
            addressStreet: client.addressStreet,
            addressPostalCode: client.addressPostalCode,
            addressCity: client.addressCity,
            addressCountryCode: client.addressCountryCode,
            privateNotes: client.privateNotes,
            isArchived: client.isArchived
        )
    }

    private static func dogSummary(_ dog: DogRecord) -> DogSummary {
        DogSummary(
            id: dog.id,
            name: dog.name,
            photoAssetID: dog.photoAssetID,
            birthDate: dog.birthDate,
            breedText: dog.breedText,
            sexRawValue: dog.sexRawValue,
            safetyFlagRawValues: dog.safetyFlagRawValues,
            safetyPrivateNote: dog.safetyPrivateNote,
            isArchived: dog.isArchived,
            roles: (dog.clientRoles ?? []).map { role in
                DogRoleSummary(
                    id: role.id,
                    clientID: role.clientID,
                    clientName: role.client?.displayName ?? String(localized: "Unknown client"),
                    kind: ClientDogRoleKind(rawValue: role.roleRawValue) ?? .other,
                    isPrimaryContact: role.isPrimaryContact
                )
            }.sorted { lhs, rhs in
                if lhs.isPrimaryContact != rhs.isPrimaryContact { return lhs.isPrimaryContact }
                return lhs.clientName.localizedStandardCompare(rhs.clientName) == .orderedAscending
            }
        )
    }
}
