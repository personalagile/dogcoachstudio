import Foundation
import PDFKit
import SwiftData
import Testing
@testable import DogCoachStudio

@Suite("Phase 5 packages, ledger and reports")
struct PackageAndReportTests {
    @Test("Package balance is derived and lifecycle reflects exhausted and expired") @MainActor
    func packageLifecycle() throws {
        let fixture = try PackageFixture()
        let active = try #require(try fixture.repository.summaries().first); #expect(active.balance == 5); #expect(active.status == .active)
        _ = try fixture.repository.adjust(packageID: active.id, units: -5, reason: "Correction")
        #expect(try fixture.repository.summaries().first?.status == .exhausted)
        let expiredID = try fixture.repository.createPackage(.init(dogID: fixture.dog.id, name: "Old", unitType: .session, initialUnits: 2, purchasedAt: fixture.now, expiresAt: fixture.now.addingTimeInterval(-1), paymentStatus: .paid, price: nil, currencyCode: nil))
        #expect(try fixture.repository.summaries().first(where: { $0.id == expiredID })?.status == .expired)
    }

    @Test("Redeem is unique per attendance and correction uses reversal") @MainActor
    func redeemAndReverse() throws {
        let fixture = try PackageFixture(); let package = try #require(try fixture.repository.summaries().first); let attendance = UUID()
        let redeem = try fixture.repository.redeem(packageID: package.id, attendanceID: attendance)
        #expect(throws: PackageDomainError.duplicateRedemption) { try fixture.repository.redeem(packageID: package.id, attendanceID: attendance) }
        _ = try fixture.repository.reverse(entryID: redeem, reason: "Attendance corrected")
        #expect(try fixture.repository.balance(packageID: package.id) == 5)
        #expect(throws: PackageDomainError.entryAlreadyReversed) { try fixture.repository.reverse(entryID: redeem, reason: "Again") }
    }

    @Test("Coupon can be redeemed once and creates ledger value") @MainActor
    func coupon() throws {
        let fixture = try PackageFixture(); let package = try #require(try fixture.repository.summaries().first)
        let coupon = try fixture.repository.issueCoupon(.init(code: "WELCOME", kind: .units, amount: 2, currencyCode: nil, issuedAt: fixture.now, expiresAt: nil))
        _ = try fixture.repository.redeemCoupon(couponID: coupon, packageID: package.id)
        #expect(try fixture.repository.balance(packageID: package.id) == 7)
        #expect(throws: PackageDomainError.couponAlreadyRedeemed) { try fixture.repository.redeemCoupon(couponID: coupon, packageID: package.id) }
    }

    @Test("Expired coupon is rejected without mutation") @MainActor
    func expiredCoupon() throws {
        let fixture = try PackageFixture(); let package = try #require(try fixture.repository.summaries().first)
        let coupon = try fixture.repository.issueCoupon(.init(code: "OLD", kind: .units, amount: 2, currencyCode: nil, issuedAt: fixture.now, expiresAt: fixture.now.addingTimeInterval(-1)))
        #expect(throws: PackageDomainError.couponExpired) { try fixture.repository.redeemCoupon(couponID: coupon, packageID: package.id) }
        #expect(try fixture.repository.balance(packageID: package.id) == 5)
    }

    @Test("Ledger CSV contains append-only audit fields") @MainActor
    func csv() throws {
        let fixture = try PackageFixture(); let package = try #require(try fixture.repository.summaries().first)
        _ = try fixture.repository.adjust(packageID: package.id, units: 1, reason: "Quoted, \"reason\"")
        let csv = String(decoding: try fixture.repository.csv(packageID: package.id).data, as: UTF8.self)
        #expect(csv.contains("reversesEntryID")); #expect(csv.contains("\"Quoted, \"\"reason\"\"\""))
    }

    @Test("Report composer is deterministic, localized and excludes private canaries")
    func reportPrivacy() {
        let input = ReportCompositionInput(dogName: "Milo", sessionTitle: "Group", sessionDate: Date(timeIntervalSince1970: 1_800_000_000), results: [.init(exerciseTitle: "Orientation", goal: "Look voluntarily", outcome: .independent, clientFacingNote: "Great progress")])
        let en = ReportComposer.compose(input, locale: .en); let de = ReportComposer.compose(input, locale: .de)
        #expect(en == ReportComposer.compose(input, locale: .en)); #expect(en.plainText.contains("Independent")); #expect(de.plainText.contains("Selbstständig"))
        #expect(!en.plainText.contains("PRIVATE CANARY")); #expect(!de.plainText.contains("PRIVATE CANARY"))
    }

    @Test("Export requires trainer approval") @MainActor
    func approval() throws {
        let fixture = try PackageFixture(); let report = ClientReportRecord(dogID: fixture.dog.id, completedSessionID: UUID(), localeIdentifier: "en"); fixture.context.insert(report); try fixture.context.save()
        let repository = ReportRepository(context: fixture.context, clock: FixedAppClock(date: fixture.now))
        #expect(throws: ReportApprovalError.approvalRequired) { try repository.markExported(reportID: report.id) }
        try repository.approve(reportID: report.id); try repository.markExported(reportID: report.id); #expect(report.exportedAt == fixture.now)
    }

    @Test("Text and multi-page A4/Letter PDF exports render") @MainActor
    func exports() throws {
        let long = ReportCompositionInput(dogName: "Milo", sessionTitle: "Long session", sessionDate: .now, results: (0..<180).map { .init(exerciseTitle: "Exercise \($0)", goal: String(repeating: "Long accessible training detail. ", count: 5), outcome: .independent, clientFacingNote: nil) })
        let report = ReportComposer.compose(long, locale: .en); #expect(String(decoding: ReportExporter.text(report).data, as: UTF8.self) == report.plainText)
        for paper in [ReportPaperSize.a4, .letter] { let artifact = ReportExporter.pdf(report, paper: paper); let pdf = try #require(PDFDocument(data: artifact.data)); #expect(pdf.pageCount > 1) }
    }
}

@MainActor private final class PackageFixture {
    let container: ModelContainer; let context: ModelContext; let repository: PackageLedgerRepository; let dog: DogRecord; let now = Date(timeIntervalSince1970: 1_800_000_000)
    init() throws { container = try ModelContainerFactory.makeInMemory(); context = container.mainContext; dog = DogRecord(name: "Milo", createdAt: now); context.insert(dog); repository = .init(context: context, uuid: SystemUUIDGenerator(), clock: FixedAppClock(date: now)); _ = try repository.createPackage(.init(dogID: dog.id, name: "Five", unitType: .session, initialUnits: 5, purchasedAt: now, expiresAt: nil, paymentStatus: .paid, price: 50, currencyCode: "EUR")) }
}
