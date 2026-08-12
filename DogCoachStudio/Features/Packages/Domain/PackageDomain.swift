import Foundation

enum PackageUnitType: String, CaseIterable, Sendable { case session, lesson, hour }
enum PackagePaymentStatus: String, CaseIterable, Sendable { case unknown, unpaid, paid, refunded }
enum PackageLifecycleStatus: String, Sendable { case active, exhausted, expired, closed }
enum PackageLedgerKind: String, CaseIterable, Sendable { case purchase, adjustment, redeem, coupon, reversal }
enum CouponKind: String, CaseIterable, Sendable { case units, value }
enum CouponStatus: String, Sendable { case available, redeemed, expired }

struct TrainingPackageDraft: Sendable {
    let dogID: UUID
    let name: String
    let unitType: PackageUnitType
    let initialUnits: Decimal
    let purchasedAt: Date
    let expiresAt: Date?
    let paymentStatus: PackagePaymentStatus
    let price: Decimal?
    let currencyCode: String?
    var clientID: UUID? = nil
    var packageTemplateID: UUID? = nil
}

struct TrainingPackageSummary: Identifiable, Hashable, Sendable {
    let id: UUID
    let dogID: UUID
    let dogName: String
    let name: String
    let balance: Decimal
    let initialUnits: Decimal
    let expiresAt: Date?
    let paymentStatus: PackagePaymentStatus
    let status: PackageLifecycleStatus
    let clientID: UUID?
    let clientName: String
    let price: Decimal?
    let currencyCode: String?
    let packageTemplateID: UUID?
    let packageTemplateName: String?
}

struct PackageTemplateDraft: Sendable {
    let name: String
    let unitType: PackageUnitType
    let units: Decimal
    let price: Decimal
    let currencyCode: String
}

struct PackageTemplateSummary: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let unitType: PackageUnitType
    let units: Decimal
    let price: Decimal
    let currencyCode: String
    let salesCount: Int
}

struct CouponDraft: Sendable {
    let code: String
    let kind: CouponKind
    let amount: Decimal
    let currencyCode: String?
    let issuedAt: Date
    let expiresAt: Date?
}

enum PackageDomainError: Error, Equatable, Sendable {
    case dogNotFound
    case clientNotFound
    case templateNotFound
    case packageNotFound
    case invalidName
    case invalidUnits
    case invalidAmount
    case couponNotFound
    case couponAlreadyRedeemed
    case couponExpired
    case currencyMismatch
    case duplicateRedemption
    case reversalRequired
    case entryNotFound
    case entryAlreadyReversed
    case packageHasHistory
}

struct LedgerCSV: Sendable { let filename: String; let data: Data }
