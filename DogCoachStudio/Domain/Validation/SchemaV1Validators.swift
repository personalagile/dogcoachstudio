import Foundation

enum SchemaV1ValidationError: Error, Equatable, Sendable {
    case missingRelationship(entity: String, relatedID: UUID)
    case duplicateDomainKey(entity: String)
    case invalidLedgerEntry(reason: String)
}

enum SchemaV1Validators {
    static func validate(_ role: ClientDogRoleRecord) throws {
        guard role.client?.id == role.clientID else {
            throw SchemaV1ValidationError.missingRelationship(entity: "ClientDogRole.client", relatedID: role.clientID)
        }
        guard role.dog?.id == role.dogID else {
            throw SchemaV1ValidationError.missingRelationship(entity: "ClientDogRole.dog", relatedID: role.dogID)
        }
    }

    static func validateUniqueRoles(_ roles: [ClientDogRoleRecord]) throws {
        struct Key: Hashable { let clientID: UUID; let dogID: UUID; let role: String }
        let keys = roles.map { Key(clientID: $0.clientID, dogID: $0.dogID, role: $0.roleRawValue) }
        guard Set(keys).count == keys.count else {
            throw SchemaV1ValidationError.duplicateDomainKey(entity: "ClientDogRole")
        }
    }

    static func validateUniqueCompletionTokens(_ sessions: [CompletedSessionRecord]) throws {
        guard Set(sessions.map(\.completionToken)).count == sessions.count else {
            throw SchemaV1ValidationError.duplicateDomainKey(entity: "CompletedSession.completionToken")
        }
    }

    static func validateLedgerEntry(_ entry: PackageLedgerEntryRecord) throws {
        guard entry.package?.id == entry.packageID else {
            throw SchemaV1ValidationError.missingRelationship(entity: "PackageLedgerEntry.package", relatedID: entry.packageID)
        }
        if entry.kindRawValue == "reversal" && entry.reversesEntryID == nil {
            throw SchemaV1ValidationError.invalidLedgerEntry(reason: "A reversal must reference the original entry.")
        }
        if entry.kindRawValue == "redeem" && entry.attendanceID == nil {
            throw SchemaV1ValidationError.invalidLedgerEntry(reason: "A redemption must reference attendance.")
        }
    }

    static func validateSingleRedemptionPerAttendance(_ entries: [PackageLedgerEntryRecord]) throws {
        let keys = entries.compactMap { entry -> String? in
            guard entry.kindRawValue == "redeem", let attendanceID = entry.attendanceID else { return nil }
            return "\(entry.packageID.uuidString)|\(attendanceID.uuidString)"
        }
        guard Set(keys).count == keys.count else {
            throw SchemaV1ValidationError.duplicateDomainKey(entity: "PackageLedgerEntry.redeem")
        }
    }
}
