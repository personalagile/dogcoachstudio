import Foundation
import SwiftData

@MainActor
final class PackageLedgerRepository {
    private let context: ModelContext
    private let uuid: any UUIDGenerating
    private let clock: any AppClock

    init(context: ModelContext, uuid: any UUIDGenerating, clock: any AppClock) {
        self.context = context; self.uuid = uuid; self.clock = clock
        try? backfillLegacyOwners()
    }

    func createPackage(_ draft: TrainingPackageDraft) throws -> UUID {
        let dog = try context.fetch(FetchDescriptor<DogRecord>()).first(where: { $0.id == draft.dogID })
        if draft.clientID == nil, dog == nil { throw PackageDomainError.dogNotFound }
        let inferredClient = (dog?.clientRoles ?? []).first(where: \.isPrimaryContact)?.client ?? (dog?.clientRoles ?? []).first?.client
        let client = try draft.clientID.flatMap { id in try context.fetch(FetchDescriptor<ClientRecord>()).first { $0.id == id } } ?? inferredClient
        if draft.clientID != nil, client == nil { throw PackageDomainError.clientNotFound }
        let template = try draft.packageTemplateID.flatMap { id in try context.fetch(FetchDescriptor<PackageTemplateRecord>()).first { $0.id == id } }
        if draft.packageTemplateID != nil, template == nil { throw PackageDomainError.templateNotFound }
        guard !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw PackageDomainError.invalidName }
        guard draft.initialUnits > 0 else { throw PackageDomainError.invalidUnits }
        let package = TrainingPackageRecord(id: uuid.makeUUID(), dogID: dog?.id ?? draft.dogID, name: draft.name, initialUnits: draft.initialUnits, purchasedAt: draft.purchasedAt)
        package.clientID = client?.id; package.client = client; package.packageTemplateID = template?.id; package.packageTemplate = template
        package.unitTypeRawValue = draft.unitType.rawValue; package.expiresAt = draft.expiresAt; package.paymentStatusRawValue = draft.paymentStatus.rawValue; package.priceSnapshot = draft.price; package.currencyCode = draft.currencyCode; package.dog = dog
        context.insert(package)
        if let client { client.packages = (client.packages ?? []) + [package] }
        if let template { template.packages = (template.packages ?? []) + [package] }
        let purchase = PackageLedgerEntryRecord(id: uuid.makeUUID(), packageID: package.id, kindRawValue: PackageLedgerKind.purchase.rawValue, unitDelta: 0, createdAt: draft.purchasedAt)
        purchase.moneyDelta = draft.price; purchase.currencyCode = draft.currencyCode; purchase.package = package
        context.insert(purchase); package.ledgerEntries = [purchase]
        try context.save(); return package.id
    }

    func summaries(at date: Date? = nil) throws -> [TrainingPackageSummary] {
        let now = date ?? clock.now()
        return try context.fetch(FetchDescriptor<TrainingPackageRecord>()).map { package in
            let balance = self.balance(package)
            let status: PackageLifecycleStatus = package.isClosed ? .closed : ((package.expiresAt.map { $0 < now } ?? false) ? .expired : (balance <= 0 ? .exhausted : .active))
            return .init(id: package.id, dogID: package.dogID, dogName: package.dog?.name ?? "", name: package.name, balance: balance, initialUnits: package.initialUnits, expiresAt: package.expiresAt, paymentStatus: PackagePaymentStatus(rawValue: package.paymentStatusRawValue) ?? .unknown, status: status, clientID: package.clientID, clientName: package.client?.displayName ?? "", price: package.priceSnapshot, currencyCode: package.currencyCode, packageTemplateID: package.packageTemplateID, packageTemplateName: package.packageTemplate?.name)
        }.sorted { $0.clientName.localizedStandardCompare($1.clientName) == .orderedAscending }
    }

    func updatePackage(id: UUID, draft: TrainingPackageDraft) throws {
        guard let package = try package(id) else { throw PackageDomainError.packageNotFound }
        guard !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw PackageDomainError.invalidName }
        guard draft.initialUnits > 0 else { throw PackageDomainError.invalidUnits }
        guard let clientID = draft.clientID,
              let client = try context.fetch(FetchDescriptor<ClientRecord>()).first(where: { $0.id == clientID }) else { throw PackageDomainError.clientNotFound }
        let template = try draft.packageTemplateID.flatMap { id in try context.fetch(FetchDescriptor<PackageTemplateRecord>()).first { $0.id == id } }
        if draft.packageTemplateID != nil, template == nil { throw PackageDomainError.templateNotFound }
        package.name = draft.name
        package.unitTypeRawValue = draft.unitType.rawValue
        package.initialUnits = draft.initialUnits
        package.expiresAt = draft.expiresAt
        package.paymentStatusRawValue = draft.paymentStatus.rawValue
        package.priceSnapshot = draft.price
        package.currencyCode = draft.currencyCode
        package.clientID = client.id
        package.client = client
        package.packageTemplateID = template?.id
        package.packageTemplate = template
        try context.save()
    }

    func deletePackage(id: UUID) throws {
        guard let package = try package(id) else { throw PackageDomainError.packageNotFound }
        let entries = package.ledgerEntries ?? []
        guard !entries.contains(where: { $0.kindRawValue != PackageLedgerKind.purchase.rawValue }) else { throw PackageDomainError.packageHasHistory }
        for entry in entries { context.delete(entry) }
        context.delete(package)
        try context.save()
    }

    func createTemplate(_ draft: PackageTemplateDraft) throws -> UUID {
        guard !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw PackageDomainError.invalidName }
        guard draft.units > 0 else { throw PackageDomainError.invalidUnits }
        guard draft.price >= 0 else { throw PackageDomainError.invalidAmount }
        let record = PackageTemplateRecord(id: uuid.makeUUID(), name: draft.name, units: draft.units, price: draft.price, currencyCode: draft.currencyCode, createdAt: clock.now())
        record.unitTypeRawValue = draft.unitType.rawValue; context.insert(record); try context.save(); return record.id
    }

    func templates() throws -> [PackageTemplateSummary] {
        try context.fetch(FetchDescriptor<PackageTemplateRecord>()).filter { !$0.isArchived }.map {
            PackageTemplateSummary(id: $0.id, name: $0.name, unitType: PackageUnitType(rawValue: $0.unitTypeRawValue) ?? .session, units: $0.units, price: $0.price, currencyCode: $0.currencyCode, salesCount: ($0.packages ?? []).count)
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func archiveTemplate(id: UUID) throws {
        guard let value = try context.fetch(FetchDescriptor<PackageTemplateRecord>()).first(where: { $0.id == id }) else { throw PackageDomainError.templateNotFound }
        value.isArchived = true; try context.save()
    }

    func updateTemplate(id: UUID, draft: PackageTemplateDraft) throws {
        guard let value = try context.fetch(FetchDescriptor<PackageTemplateRecord>()).first(where: { $0.id == id }) else { throw PackageDomainError.templateNotFound }
        guard !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw PackageDomainError.invalidName }
        guard draft.units > 0 else { throw PackageDomainError.invalidUnits }
        guard draft.price >= 0 else { throw PackageDomainError.invalidAmount }
        value.name = draft.name; value.unitTypeRawValue = draft.unitType.rawValue; value.units = draft.units; value.price = draft.price; value.currencyCode = draft.currencyCode
        try context.save()
    }

    func balance(packageID: UUID) throws -> Decimal { guard let package = try package(packageID) else { throw PackageDomainError.packageNotFound }; return balance(package) }

    func adjust(packageID: UUID, units: Decimal, reason: String) throws -> UUID {
        guard units != 0 else { throw PackageDomainError.invalidUnits }
        return try append(packageID: packageID, kind: .adjustment, units: units, reason: reason)
    }

    func redeem(packageID: UUID, attendanceID: UUID, units: Decimal = 1) throws -> UUID {
        guard units > 0 else { throw PackageDomainError.invalidUnits }
        let entries = try context.fetch(FetchDescriptor<PackageLedgerEntryRecord>())
        guard !entries.contains(where: { $0.packageID == packageID && $0.attendanceID == attendanceID && $0.kindRawValue == PackageLedgerKind.redeem.rawValue }) else { throw PackageDomainError.duplicateRedemption }
        let id = try append(packageID: packageID, kind: .redeem, units: -units, reason: nil)
        let entry = try context.fetch(FetchDescriptor<PackageLedgerEntryRecord>()).first { $0.id == id }!; entry.attendanceID = attendanceID; try context.save(); return id
    }

    func reverse(entryID: UUID, reason: String) throws -> UUID {
        let entries = try context.fetch(FetchDescriptor<PackageLedgerEntryRecord>())
        guard let original = entries.first(where: { $0.id == entryID }) else { throw PackageDomainError.entryNotFound }
        guard original.kindRawValue != PackageLedgerKind.reversal.rawValue else { throw PackageDomainError.reversalRequired }
        guard !entries.contains(where: { $0.reversesEntryID == entryID }) else { throw PackageDomainError.entryAlreadyReversed }
        let id = try append(packageID: original.packageID, kind: .reversal, units: -original.unitDelta, reason: reason)
        let reversal = try context.fetch(FetchDescriptor<PackageLedgerEntryRecord>()).first { $0.id == id }!
        reversal.reversesEntryID = original.id; reversal.reversesEntry = original
        reversal.moneyDelta = original.moneyDelta.map { -$0 }; reversal.currencyCode = original.currencyCode
        try context.save(); return id
    }

    func issueCoupon(_ draft: CouponDraft) throws -> UUID {
        guard draft.amount > 0 else { throw PackageDomainError.invalidAmount }
        let code = draft.code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { throw PackageDomainError.invalidName }
        let coupon = CouponRecord(id: uuid.makeUUID(), code: code, kindRawValue: draft.kind.rawValue, amount: draft.amount, issuedAt: draft.issuedAt)
        coupon.currencyCode = draft.currencyCode; coupon.expiresAt = draft.expiresAt; context.insert(coupon); try context.save(); return coupon.id
    }

    func redeemCoupon(couponID: UUID, packageID: UUID) throws -> UUID {
        guard let coupon = try context.fetch(FetchDescriptor<CouponRecord>()).first(where: { $0.id == couponID }) else { throw PackageDomainError.couponNotFound }
        guard coupon.redeemedAt == nil else { throw PackageDomainError.couponAlreadyRedeemed }
        guard coupon.expiresAt.map({ $0 >= clock.now() }) ?? true else { throw PackageDomainError.couponExpired }
        guard let package = try package(packageID) else { throw PackageDomainError.packageNotFound }
        if coupon.kindRawValue == CouponKind.value.rawValue, coupon.currencyCode != package.currencyCode { throw PackageDomainError.currencyMismatch }
        let units = coupon.kindRawValue == CouponKind.units.rawValue ? coupon.amount : 0
        let id = try append(packageID: packageID, kind: .coupon, units: units, reason: "Coupon \(coupon.code)")
        let entry = try context.fetch(FetchDescriptor<PackageLedgerEntryRecord>()).first { $0.id == id }!; entry.moneyDelta = coupon.kindRawValue == CouponKind.value.rawValue ? coupon.amount : nil; entry.currencyCode = coupon.currencyCode
        coupon.redeemedAt = clock.now(); coupon.redeemedPackageID = packageID; coupon.redeemedPackage = package; try context.save(); return id
    }

    func csv(packageID: UUID) throws -> LedgerCSV {
        guard try package(packageID) != nil else { throw PackageDomainError.packageNotFound }
        let rows = try context.fetch(FetchDescriptor<PackageLedgerEntryRecord>()).filter { $0.packageID == packageID }.sorted { $0.createdAt < $1.createdAt }
        let iso = ISO8601DateFormatter()
        let body = (["id,createdAt,kind,unitDelta,moneyDelta,currencyCode,attendanceID,reversesEntryID,reason"] + rows.map { entry in
            [entry.id.uuidString, iso.string(from: entry.createdAt), entry.kindRawValue, "\(entry.unitDelta)", entry.moneyDelta.map(String.init(describing:)) ?? "", entry.currencyCode ?? "", entry.attendanceID?.uuidString ?? "", entry.reversesEntryID?.uuidString ?? "", csvEscape(entry.reason ?? "")].joined(separator: ",")
        }).joined(separator: "\n")
        return .init(filename: "package-ledger-\(packageID.uuidString).csv", data: Data(body.utf8))
    }

    private func balance(_ package: TrainingPackageRecord) -> Decimal { package.initialUnits + (package.ledgerEntries ?? []).reduce(Decimal.zero) { $0 + $1.unitDelta } }
    private func package(_ id: UUID) throws -> TrainingPackageRecord? { try context.fetch(FetchDescriptor<TrainingPackageRecord>()).first { $0.id == id } }
    private func append(packageID: UUID, kind: PackageLedgerKind, units: Decimal, reason: String?) throws -> UUID {
        guard let package = try package(packageID) else { throw PackageDomainError.packageNotFound }
        let entry = PackageLedgerEntryRecord(id: uuid.makeUUID(), packageID: packageID, kindRawValue: kind.rawValue, unitDelta: units, createdAt: clock.now()); entry.reason = reason; entry.package = package; context.insert(entry); package.ledgerEntries = (package.ledgerEntries ?? []) + [entry]; try context.save(); return entry.id
    }
    private func csvEscape(_ value: String) -> String { "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\"" }
    private func backfillLegacyOwners() throws {
        for package in try context.fetch(FetchDescriptor<TrainingPackageRecord>()) where package.clientID == nil {
            let client = (package.dog?.clientRoles ?? []).first(where: \.isPrimaryContact)?.client ?? (package.dog?.clientRoles ?? []).first?.client
            package.clientID = client?.id; package.client = client
        }
        if context.hasChanges { try context.save() }
    }
}
