import Foundation
import Testing
@testable import DogCoachStudio

@Suite("Phase 8 sync spike and hardening")
struct SyncAndHardeningTests {
    @Test("Independent changes merge without losing IDs")
    func independentMerge() throws {
        let localToken = UUID(), remoteToken = UUID()
        let local = SyncInvariantSnapshot(completions: [localToken: .init(token: localToken, fingerprint: "a")], redemptions: [:])
        let remote = SyncInvariantSnapshot(completions: [remoteToken: .init(token: remoteToken, fingerprint: "b")], redemptions: [:])
        let merged = try SyncInvariantMerger.merge(local: local, remote: remote)
        #expect(merged.completions.count == 2)
    }

    @Test("Same completion token with different payload is never silently merged")
    func completionConflict() {
        let token = UUID()
        let local = SyncInvariantSnapshot(completions: [token: .init(token: token, fingerprint: "a")], redemptions: [:])
        let remote = SyncInvariantSnapshot(completions: [token: .init(token: token, fingerprint: "b")], redemptions: [:])
        #expect(throws: SyncConflictError.completionPayloadConflict(token)) { try SyncInvariantMerger.merge(local: local, remote: remote) }
    }

    @Test("Different ledger IDs for one attendance and package are rejected")
    func redemptionConflict() {
        let attendance = UUID(), package = UUID()
        let key = SyncInvariantMerger.redemptionKey(attendanceID: attendance, packageID: package)
        let localValue = SyncRedemptionDigest(attendanceID: attendance, packageID: package, ledgerEntryID: UUID())
        let remoteValue = SyncRedemptionDigest(attendanceID: attendance, packageID: package, ledgerEntryID: UUID())
        let local = SyncInvariantSnapshot(completions: [:], redemptions: [key: localValue])
        let remote = SyncInvariantSnapshot(completions: [:], redemptions: [key: remoteValue])
        #expect(throws: SyncConflictError.duplicateRedemption(key)) { try SyncInvariantMerger.merge(local: local, remote: remote) }
    }

    @Test("No-Go sync decision preserves local operation and export")
    func localFallback() {
        let availability = PersonalSyncAvailability(decision: .localOnlyWithExport)
        #expect(!availability.isOptInAvailable)
        #expect(availability.localFallbackAvailable)
        #expect(availability.statusText.contains("backup"))
    }
}
