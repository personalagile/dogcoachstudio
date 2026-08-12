import Foundation
import Testing
@testable import DogCoachStudio

@Suite("Phase 7 commerce and approved catalog")
struct CommerceAndCatalogTests {
    @Test("Product identifiers match StoreKit configuration")
    func productIdentifiers() throws {
        let url = try #require(Bundle.main.url(forResource: "Products", withExtension: "storekit"))
        let text = try String(contentsOf: url, encoding: .utf8)
        for product in CommerceProductID.allCases { #expect(text.contains(product.rawValue)) }
    }

    @Test("Verified, pending, and refunded transactions update local entitlements")
    func entitlementTransitions() {
        var snapshot = EntitlementSnapshot()
        snapshot.markPending(productID: CommerceProductID.proMonthly.rawValue)
        #expect(snapshot.pendingProductIDs.contains(CommerceProductID.proMonthly.rawValue))
        snapshot.applyVerified(productID: CommerceProductID.proMonthly.rawValue, revoked: false)
        #expect(snapshot.hasPro)
        #expect(snapshot.pendingProductIDs.isEmpty)
        snapshot.applyVerified(productID: CommerceProductID.proMonthly.rawValue, revoked: true)
        #expect(!snapshot.hasPro)
    }

    @Test("Expired access never blocks reading or export")
    func fairAccessPolicy() {
        let expired = EntitlementSnapshot()
        #expect(AccessPolicy.canReadAndExportData(snapshot: expired))
        #expect(!AccessPolicy.canCreateNewBusinessRecords(snapshot: expired))
    }

    @Test("Foundation pack has approved German and English low-risk content")
    func approvedFoundationPack() throws {
        let url = try #require(Bundle.main.url(forResource: "foundation-v1", withExtension: "json"))
        let pack = try ContentPackValidator.decodeAndValidate(Data(contentsOf: url))
        #expect(pack.reviewStatus == .approved)
        #expect(!pack.author.isEmpty)
        #expect(!pack.license.isEmpty)
        #expect(pack.exercises.allSatisfy { Set($0.localizations.keys) == Set(["de", "en"]) })
        #expect(pack.exercises.allSatisfy { $0.metadata.safetyLevel == .standard })
    }
}
