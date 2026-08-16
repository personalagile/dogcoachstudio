import Foundation
import SwiftData
import Testing
@testable import DogCoachStudio

@Suite("Phase 16 finance analytics and export")
struct FinancePhase16Tests {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    @Test("Period filters, refunds, and currencies produce deterministic KPIs")
    func analytics() throws {
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 5, day: 15)))
        let april = try #require(calendar.date(from: DateComponents(year: 2026, month: 4, day: 2)))
        let may = try #require(calendar.date(from: DateComponents(year: 2026, month: 5, day: 2)))
        let march = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 2)))
        let events = [
            event(id: 1, date: may, package: "Ten sessions", amount: 100, currency: "EUR"),
            event(id: 2, date: may, package: "Ten sessions", amount: -20, currency: "EUR"),
            event(id: 3, date: april, package: "Starter", amount: 50, currency: "EUR"),
            event(id: 4, date: march, package: "Starter", amount: 40, currency: "EUR"),
            event(id: 5, date: may, package: "USD package", amount: 200, currency: "USD")
        ]

        let month = FinanceAnalytics.snapshot(events: events, period: .month, currencyCode: "EUR", now: now, calendar: calendar)
        #expect(month.totalRevenue == 80)
        #expect(month.salesCount == 1)
        #expect(month.averageSale == 80)
        #expect(month.transactions.count == 2)
        #expect(month.packages == [.init(name: "Ten sessions", revenue: 80, salesCount: 1)])
        #expect(month.clients == [.init(name: "Client", revenue: 80, salesCount: 1)])

        let quarter = FinanceAnalytics.snapshot(events: events, period: .quarter, currencyCode: "EUR", now: now, calendar: calendar)
        #expect(quarter.totalRevenue == 130)
        #expect(quarter.salesCount == 2)
        #expect(quarter.timeline.count == 2)

        let year = FinanceAnalytics.snapshot(events: events, period: .year, currencyCode: "USD", now: now, calendar: calendar)
        #expect(year.totalRevenue == 200)
        #expect(year.transactions.count == 1)
    }

    @Test("Top clients are ranked by revenue and keep their sale count")
    func topClients() {
        let snapshot = FinanceAnalytics.snapshot(
            events: [
                event(id: 1, date: .now, client: "Sam", package: "Five", amount: 50, currency: "EUR"),
                event(id: 2, date: .now, client: "Alex", package: "Ten", amount: 120, currency: "EUR"),
                event(id: 3, date: .now, client: "Sam", package: "Five", amount: 50, currency: "EUR")
            ],
            period: .all,
            currencyCode: "EUR",
            now: .now,
            calendar: calendar
        )

        #expect(snapshot.clients == [
            .init(name: "Alex", revenue: 120, salesCount: 1),
            .init(name: "Sam", revenue: 100, salesCount: 2)
        ])
    }

    @Test("Finance is derived only from purchase ledger entries and their reversals") @MainActor
    func repositoryUsesLedger() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let client = ClientRecord(displayName: "Alex Example")
        context.insert(client)
        try context.save()
        let packages = PackageLedgerRepository(context: context, uuid: SystemUUIDGenerator(), clock: SystemAppClock())
        let packageID = try packages.createPackage(.init(
            dogID: UUID(), name: "Coaching", unitType: .session, initialUnits: 5,
            purchasedAt: .now, expiresAt: nil, paymentStatus: .paid,
            price: 120, currencyCode: "EUR", clientID: client.id
        ))
        _ = try packages.adjust(packageID: packageID, units: 1, reason: "Correction")
        _ = try packages.redeem(packageID: packageID, attendanceID: UUID())

        let finance = FinanceRepository(context: context)
        #expect(try finance.ledgerEvents().map(\.amount) == [120])
        let purchase = try #require(try context.fetch(FetchDescriptor<PackageLedgerEntryRecord>()).first { $0.kindRawValue == PackageLedgerKind.purchase.rawValue })
        _ = try packages.reverse(entryID: purchase.id, reason: "Refund")
        let events = try finance.ledgerEvents()
        #expect(events.count == 2)
        #expect(events.reduce(Decimal.zero) { $0 + $1.amount } == 0)
    }

    @Test("CSV is stable and escapes user-provided names")
    func csv() throws {
        let snapshot = FinanceAnalytics.snapshot(
            events: [event(id: 1, date: Date(timeIntervalSince1970: 0), client: "Client, \"One\"", package: "Five, Pack", amount: 75, currency: "EUR")],
            period: .all,
            currencyCode: "EUR",
            now: .now,
            calendar: calendar
        )
        let file = FinanceCSVExporter.export(snapshot)
        let text = try #require(String(data: file.data, encoding: .utf8))
        #expect(file.filename == "finance-all-eur.csv")
        #expect(text.hasPrefix("date,client,package,packageTemplate,amount,currencyCode\n"))
        #expect(text.contains("\"Client, \"\"One\"\"\""))
        #expect(text.contains("\"Five, Pack\""))
    }

    private func event(
        id: Int,
        date: Date,
        client: String = "Client",
        package: String,
        amount: Decimal,
        currency: String
    ) -> FinanceLedgerEvent {
        FinanceLedgerEvent(
            id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", id))!,
            date: date,
            clientName: client,
            packageName: package,
            packageTemplateName: nil,
            amount: amount,
            currencyCode: currency
        )
    }
}
