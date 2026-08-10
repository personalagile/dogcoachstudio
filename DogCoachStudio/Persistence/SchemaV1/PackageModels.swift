import Foundation
import SwiftData

@Model
final class TrainingPackageRecord {
    var id: UUID = UUID()
    var dogID: UUID = UUID()
    var name: String = ""
    var unitTypeRawValue: String = "session"
    var initialUnits: Decimal = 0
    var purchasedAt: Date = Date()
    var expiresAt: Date?
    var paymentStatusRawValue: String = "unknown"
    var priceSnapshot: Decimal?
    var currencyCode: String?
    var isClosed: Bool = false
    var dog: DogRecord?
    var ledgerEntries: [PackageLedgerEntryRecord]?

    init(id: UUID = UUID(), dogID: UUID, name: String, initialUnits: Decimal, purchasedAt: Date = .now) {
        self.id = id
        self.dogID = dogID
        self.name = name
        self.initialUnits = initialUnits
        self.purchasedAt = purchasedAt
    }
}

@Model
final class PackageLedgerEntryRecord {
    var id: UUID = UUID()
    var packageID: UUID = UUID()
    var kindRawValue: String = "purchase"
    var unitDelta: Decimal = 0
    var moneyDelta: Decimal?
    var currencyCode: String?
    var attendanceID: UUID?
    var reversesEntryID: UUID?
    var reason: String?
    var createdAt: Date = Date()
    var package: TrainingPackageRecord?
    var attendance: AttendanceRecord?
    var reversesEntry: PackageLedgerEntryRecord?

    init(
        id: UUID = UUID(),
        packageID: UUID,
        kindRawValue: String,
        unitDelta: Decimal,
        createdAt: Date = .now
    ) {
        self.id = id
        self.packageID = packageID
        self.kindRawValue = kindRawValue
        self.unitDelta = unitDelta
        self.createdAt = createdAt
    }
}

@Model
final class CouponRecord {
    var id: UUID = UUID()
    var code: String = ""
    var kindRawValue: String = "units"
    var amount: Decimal = 0
    var currencyCode: String?
    var issuedAt: Date = Date()
    var expiresAt: Date?
    var redeemedAt: Date?
    var redeemedPackageID: UUID?
    var redeemedPackage: TrainingPackageRecord?

    init(id: UUID = UUID(), code: String, kindRawValue: String, amount: Decimal, issuedAt: Date = .now) {
        self.id = id
        self.code = code
        self.kindRawValue = kindRawValue
        self.amount = amount
        self.issuedAt = issuedAt
    }
}
