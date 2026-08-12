import Foundation

enum PersonalSyncDecision: String, Codable, Sendable {
    case localOnlyWithExport
    case cloudKitApproved
}

struct SyncCompletionDigest: Equatable, Sendable {
    let token: UUID
    let fingerprint: String
}

struct SyncRedemptionDigest: Equatable, Hashable, Sendable {
    let attendanceID: UUID
    let packageID: UUID
    let ledgerEntryID: UUID
}

struct SyncInvariantSnapshot: Equatable, Sendable {
    var completions: [UUID: SyncCompletionDigest]
    var redemptions: [String: SyncRedemptionDigest]
}

enum SyncConflictError: Error, Equatable, Sendable {
    case completionPayloadConflict(UUID)
    case duplicateRedemption(String)
}

enum SyncInvariantMerger {
    static func merge(local: SyncInvariantSnapshot, remote: SyncInvariantSnapshot) throws -> SyncInvariantSnapshot {
        var completions = local.completions
        for (token, remoteValue) in remote.completions {
            if let localValue = completions[token], localValue != remoteValue {
                throw SyncConflictError.completionPayloadConflict(token)
            }
            completions[token] = remoteValue
        }

        var redemptions = local.redemptions
        for (key, remoteValue) in remote.redemptions {
            if let localValue = redemptions[key], localValue != remoteValue {
                throw SyncConflictError.duplicateRedemption(key)
            }
            redemptions[key] = remoteValue
        }
        return SyncInvariantSnapshot(completions: completions, redemptions: redemptions)
    }

    static func redemptionKey(attendanceID: UUID, packageID: UUID) -> String {
        attendanceID.uuidString + ":" + packageID.uuidString
    }
}

struct PersonalSyncAvailability: Equatable, Sendable {
    let decision: PersonalSyncDecision
    var isOptInAvailable: Bool { decision == .cloudKitApproved }
    var localFallbackAvailable: Bool { true }
    var statusText: String {
        switch decision {
        case .localOnlyWithExport: "Stored locally — backup available"
        case .cloudKitApproved: "iCloud sync available"
        }
    }
}
