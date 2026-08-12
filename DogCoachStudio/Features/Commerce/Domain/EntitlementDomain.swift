import Foundation

enum CommerceProductID: String, CaseIterable, Codable, Sendable {
    case proMonthly = "studio.dogcoach.pro.monthly"
    case proAnnual = "studio.dogcoach.pro.annual"
    case foundationPack = "studio.dogcoach.pack.foundation"
}

enum PurchaseState: Equatable, Sendable {
    case idle
    case loading
    case purchasing(CommerceProductID)
    case pending(CommerceProductID)
    case active
    case failed
}

struct EntitlementSnapshot: Equatable, Sendable {
    var activeProductIDs: Set<String> = []
    var pendingProductIDs: Set<String> = []

    var hasPro: Bool {
        activeProductIDs.contains(CommerceProductID.proMonthly.rawValue) ||
        activeProductIDs.contains(CommerceProductID.proAnnual.rawValue)
    }

    var hasFoundationPack: Bool { activeProductIDs.contains(CommerceProductID.foundationPack.rawValue) }

    mutating func applyVerified(productID: String, revoked: Bool) {
        pendingProductIDs.remove(productID)
        if revoked { activeProductIDs.remove(productID) } else { activeProductIDs.insert(productID) }
    }

    mutating func markPending(productID: String) { pendingProductIDs.insert(productID) }
}

enum AccessPolicy {
    static func canReadAndExportData(snapshot: EntitlementSnapshot) -> Bool { true }
    static func canCreateNewBusinessRecords(snapshot: EntitlementSnapshot) -> Bool { snapshot.hasPro }
}
