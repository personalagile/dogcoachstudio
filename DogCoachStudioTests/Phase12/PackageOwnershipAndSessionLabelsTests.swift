import Foundation
import SwiftData
import Testing
@testable import DogCoachStudio

@Suite("Phase 12 client packages, templates, and session metadata")
struct PackageOwnershipAndSessionLabelsTests {
    @Test("A priced template tracks sales to client-owned packages") @MainActor
    func templateSales() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let client = ClientRecord(displayName: "Alex")
        context.insert(client); try context.save()
        let repository = PackageLedgerRepository(context: context, uuid: SystemUUIDGenerator(), clock: SystemAppClock())
        let templateID = try repository.createTemplate(.init(name: "Ten sessions", unitType: .session, units: 10, price: 190, currencyCode: "EUR"))
        _ = try repository.createPackage(.init(dogID: UUID(), name: "Ten sessions", unitType: .session, initialUnits: 10, purchasedAt: .now, expiresAt: nil, paymentStatus: .paid, price: 190, currencyCode: "EUR", clientID: client.id, packageTemplateID: templateID))
        let package = try #require(try repository.summaries().first)
        let template = try #require(try repository.templates().first)
        #expect(package.clientID == client.id)
        #expect(package.clientName == "Alex")
        #expect(package.price == 190)
        #expect(template.salesCount == 1)
    }

    @Test("A sold package can be edited and deleted before consumption") @MainActor
    func packageCRUD() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let client = ClientRecord(displayName: "Sam")
        context.insert(client); try context.save()
        let repository = PackageLedgerRepository(context: context, uuid: SystemUUIDGenerator(), clock: SystemAppClock())
        let packageID = try repository.createPackage(.init(dogID: UUID(), name: "Five", unitType: .session, initialUnits: 5, purchasedAt: .now, expiresAt: nil, paymentStatus: .paid, price: 80, currencyCode: "EUR", clientID: client.id))
        try repository.updatePackage(id: packageID, draft: .init(dogID: UUID(), name: "Six", unitType: .session, initialUnits: 6, purchasedAt: .now, expiresAt: nil, paymentStatus: .paid, price: 95, currencyCode: "EUR", clientID: client.id))
        let updated = try #require(try repository.summaries().first)
        #expect(updated.name == "Six")
        #expect(updated.initialUnits == 6)
        #expect(updated.price == 95)
        try repository.deletePackage(id: packageID)
        #expect(try repository.summaries().isEmpty)
        #expect(try context.fetchCount(FetchDescriptor<PackageLedgerEntryRecord>()) == 0)
    }

    @Test("A consumed package cannot be deleted because it is financial history") @MainActor
    func consumedPackageIsProtected() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let client = ClientRecord(displayName: "Robin")
        context.insert(client); try context.save()
        let repository = PackageLedgerRepository(context: context, uuid: SystemUUIDGenerator(), clock: SystemAppClock())
        let packageID = try repository.createPackage(.init(dogID: UUID(), name: "Course", unitType: .session, initialUnits: 5, purchasedAt: .now, expiresAt: nil, paymentStatus: .paid, price: 100, currencyCode: "EUR", clientID: client.id))
        _ = try repository.redeem(packageID: packageID, attendanceID: UUID())
        #expect(throws: PackageDomainError.packageHasHistory) { try repository.deletePackage(id: packageID) }
        #expect(try repository.summaries().count == 1)
    }

    @Test("Legacy dog packages are assigned to the primary client") @MainActor
    func legacyOwnerBackfill() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let client = ClientRecord(displayName: "Primary")
        let dog = DogRecord(name: "Milo")
        let role = ClientDogRoleRecord(clientID: client.id, dogID: dog.id, isPrimaryContact: true)
        role.client = client; role.dog = dog; client.dogRoles = [role]; dog.clientRoles = [role]
        let package = TrainingPackageRecord(dogID: dog.id, name: "Legacy", initialUnits: 3)
        package.dog = dog
        context.insert(client); context.insert(dog); context.insert(role); context.insert(package); try context.save()
        let repository = PackageLedgerRepository(context: context, uuid: SystemUUIDGenerator(), clock: SystemAppClock())
        let summary = try #require(try repository.summaries().first)
        #expect(summary.clientID == client.id)
        #expect(summary.clientName == "Primary")
    }

    @Test("Session labels and package consumption persist") @MainActor
    func labels() throws {
        let fixture = try Phase4Fixture(dogCount: 1)
        let created = try fixture.sessions.create(.init(title: "Tagged", startAt: fixture.now.addingTimeInterval(10_000), durationMinutes: 45, locationText: nil, kind: .group, templateVersionID: nil, dogIDs: fixture.dogIDs, labels: [" Recall ", "GROUP", "recall"], packageUnitsPerAttendee: 0))
        let summary = try #require(try fixture.sessions.list().first { $0.id == created })
        #expect(summary.labels == ["group", "recall"])
        #expect(summary.packageUnitsPerAttendee == 0)
    }

    @Test("A zero-unit trial creates reports but no package redemption") @MainActor
    func zeroUnitTrial() throws {
        let fixture = try Phase4Fixture(dogCount: 1)
        let session = try #require(try fixture.sessions.session(id: fixture.sessionID))
        session.packageUnitsPerAttendee = 0
        try fixture.context.save()
        let result = try fixture.completion.complete(try fixture.request())
        #expect(result.reportCount == 1)
        #expect(result.redemptionCount == 0)
        #expect(try fixture.context.fetchCount(FetchDescriptor<PackageLedgerEntryRecord>()) == 0)
    }

    @Test("Schema v2 contains package templates")
    func schemaV2() {
        #expect(DogCoachSchemaV2.models.contains { $0 == PackageTemplateRecord.self })
    }
}
