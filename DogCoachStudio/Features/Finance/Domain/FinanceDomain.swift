import Foundation

enum FinancePeriod: String, CaseIterable, Sendable { case month, quarter, year, all }

struct FinanceLedgerEvent: Identifiable, Equatable, Sendable {
    let id: UUID
    let date: Date
    let clientName: String
    let packageName: String
    let packageTemplateName: String?
    let amount: Decimal
    let currencyCode: String
}

struct FinanceTimePoint: Identifiable, Equatable, Sendable {
    let start: Date
    let revenue: Decimal
    let salesCount: Int
    var id: Date { start }
}

struct FinancePackageBreakdown: Identifiable, Equatable, Sendable {
    let name: String
    let revenue: Decimal
    let salesCount: Int
    var id: String { name }
}

struct FinanceSnapshot: Equatable, Sendable {
    let period: FinancePeriod
    let currencyCode: String
    let totalRevenue: Decimal
    let salesCount: Int
    let averageSale: Decimal
    let timeline: [FinanceTimePoint]
    let packages: [FinancePackageBreakdown]
    let transactions: [FinanceLedgerEvent]
}

enum FinanceAnalytics {
    static func snapshot(
        events: [FinanceLedgerEvent],
        period: FinancePeriod,
        currencyCode: String,
        now: Date,
        calendar: Calendar = .current
    ) -> FinanceSnapshot {
        let interval = interval(for: period, now: now, calendar: calendar)
        let filtered = events.filter { event in
            event.currencyCode == currencyCode && (interval.map { $0.contains(event.date) } ?? true)
        }
        let sorted = filtered.sorted { lhs, rhs in
            lhs.date == rhs.date ? lhs.id.uuidString < rhs.id.uuidString : lhs.date > rhs.date
        }
        let total = filtered.reduce(Decimal.zero) { $0 + $1.amount }
        let salesCount = filtered.filter { $0.amount > 0 }.count
        let average = salesCount == 0 ? 0 : total / Decimal(salesCount)
        let component: Calendar.Component = period == .month ? .day : .month
        let grouped = Dictionary(grouping: filtered) { event in
            calendar.dateInterval(of: component, for: event.date)?.start ?? event.date
        }
        var timeline: [FinanceTimePoint] = []
        for (start, values) in grouped {
            let revenue = values.reduce(Decimal.zero) { partial, event in partial + event.amount }
            let count = values.filter { $0.amount > 0 }.count
            timeline.append(FinanceTimePoint(start: start, revenue: revenue, salesCount: count))
        }
        timeline.sort { $0.start < $1.start }
        let packageGroups = Dictionary(grouping: filtered) { event in
            let template = event.packageTemplateName?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let template, !template.isEmpty { return template }
            return event.packageName
        }
        var packages: [FinancePackageBreakdown] = []
        for (name, values) in packageGroups {
            let revenue = values.reduce(Decimal.zero) { partial, event in partial + event.amount }
            let count = values.filter { $0.amount > 0 }.count
            packages.append(FinancePackageBreakdown(name: name, revenue: revenue, salesCount: count))
        }
        packages.sort { lhs, rhs in
            lhs.revenue == rhs.revenue ? lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending : lhs.revenue > rhs.revenue
        }
        return FinanceSnapshot(period: period, currencyCode: currencyCode, totalRevenue: total, salesCount: salesCount, averageSale: average, timeline: timeline, packages: packages, transactions: sorted)
    }

    static func interval(for period: FinancePeriod, now: Date, calendar: Calendar) -> DateInterval? {
        switch period {
        case .month: return calendar.dateInterval(of: .month, for: now)
        case .year: return calendar.dateInterval(of: .year, for: now)
        case .quarter:
            let components = calendar.dateComponents([.year, .month], from: now)
            guard let year = components.year, let month = components.month else { return nil }
            let firstMonth = ((month - 1) / 3) * 3 + 1
            guard let start = calendar.date(from: DateComponents(year: year, month: firstMonth, day: 1)),
                  let end = calendar.date(byAdding: .month, value: 3, to: start) else { return nil }
            return DateInterval(start: start, end: end)
        case .all: return nil
        }
    }
}
