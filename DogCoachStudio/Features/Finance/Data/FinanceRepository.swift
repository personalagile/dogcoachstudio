import Foundation
import SwiftData

@MainActor
final class FinanceRepository {
    private let context: ModelContext
    private let calendar: Calendar

    init(context: ModelContext, calendar: Calendar = .current) {
        self.context = context
        self.calendar = calendar
    }

    func currencies() throws -> [String] {
        Array(Set(try ledgerEvents().map(\.currencyCode))).sorted()
    }

    func snapshot(period: FinancePeriod, currencyCode: String, now: Date) throws -> FinanceSnapshot {
        FinanceAnalytics.snapshot(events: try ledgerEvents(), period: period, currencyCode: currencyCode, now: now, calendar: calendar)
    }

    func ledgerEvents() throws -> [FinanceLedgerEvent] {
        try context.fetch(FetchDescriptor<PackageLedgerEntryRecord>()).compactMap { entry in
            let kind = PackageLedgerKind(rawValue: entry.kindRawValue)
            let isPurchase = kind == .purchase
            let isPurchaseReversal = kind == .reversal && entry.reversesEntry?.kindRawValue == PackageLedgerKind.purchase.rawValue
            guard isPurchase || isPurchaseReversal,
                  let amount = entry.moneyDelta,
                  amount != 0,
                  let currencyCode = entry.currencyCode,
                  let package = entry.package else { return nil }
            return FinanceLedgerEvent(
                id: entry.id,
                date: entry.createdAt,
                clientName: package.client?.displayName ?? String(localized: "Unknown client"),
                packageName: package.name,
                packageTemplateName: package.packageTemplate?.name,
                amount: amount,
                currencyCode: currencyCode
            )
        }
    }
}
