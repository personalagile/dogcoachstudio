import Foundation
import Testing
@testable import DogCoachStudio

@Suite("Phase 1 schema v1 validators")
struct SchemaV1ValidatorTests {
    @Test("Client-dog roles require matching object relationships")
    func roleRelationships() throws {
        let client = ClientRecord(displayName: "Client")
        let dog = DogRecord(name: "Dog")
        let role = ClientDogRoleRecord(clientID: client.id, dogID: dog.id)

        #expect(throws: SchemaV1ValidationError.self) { try SchemaV1Validators.validate(role) }

        role.client = client
        role.dog = dog
        #expect(throws: Never.self) { try SchemaV1Validators.validate(role) }
    }

    @Test("Duplicate client-dog-role domain keys are rejected")
    func uniqueRoles() {
        let clientID = UUID()
        let dogID = UUID()
        let roles = [
            ClientDogRoleRecord(clientID: clientID, dogID: dogID, roleRawValue: "owner"),
            ClientDogRoleRecord(clientID: clientID, dogID: dogID, roleRawValue: "owner")
        ]

        #expect(throws: SchemaV1ValidationError.duplicateDomainKey(entity: "ClientDogRole")) {
            try SchemaV1Validators.validateUniqueRoles(roles)
        }
    }

    @Test("Completion tokens are unique on the domain boundary")
    func uniqueCompletionTokens() {
        let token = UUID()
        let sessions = [
            CompletedSessionRecord(sessionID: UUID(), completionToken: token),
            CompletedSessionRecord(sessionID: UUID(), completionToken: token)
        ]

        #expect(throws: SchemaV1ValidationError.duplicateDomainKey(entity: "CompletedSession.completionToken")) {
            try SchemaV1Validators.validateUniqueCompletionTokens(sessions)
        }
    }

    @Test("Ledger entries require package and kind-specific references")
    func ledgerRelationships() throws {
        let package = TrainingPackageRecord(dogID: UUID(), name: "Ten sessions", initialUnits: 10)
        let redeem = PackageLedgerEntryRecord(
            packageID: package.id,
            kindRawValue: "redeem",
            unitDelta: -1
        )
        redeem.package = package

        #expect(throws: SchemaV1ValidationError.self) { try SchemaV1Validators.validateLedgerEntry(redeem) }

        redeem.attendanceID = UUID()
        #expect(throws: Never.self) { try SchemaV1Validators.validateLedgerEntry(redeem) }
    }

    @Test("Only one redemption is allowed per attendance and package")
    func singleRedemptionPerAttendance() {
        let packageID = UUID()
        let attendanceID = UUID()
        let entries = (0..<2).map { _ in
            let entry = PackageLedgerEntryRecord(
                packageID: packageID,
                kindRawValue: "redeem",
                unitDelta: -1
            )
            entry.attendanceID = attendanceID
            return entry
        }

        #expect(throws: SchemaV1ValidationError.duplicateDomainKey(entity: "PackageLedgerEntry.redeem")) {
            try SchemaV1Validators.validateSingleRedemptionPerAttendance(entries)
        }
    }
}
