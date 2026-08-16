import Charts
import Observation
import SwiftData
import SwiftUI
import UIKit

@MainActor @Observable
final class FinanceFeatureModel {
    private let repository: FinanceRepository
    private let context: ModelContext
    private let clock: any AppClock
    private let uuid: any UUIDGenerating
    private let dataChanges: AppDataChanges
    var period: FinancePeriod = .year
    var currencyCode = "EUR"
    var currencies: [String] = []
    var snapshot: FinanceSnapshot?
    var error: AppError?

    init(environment: AppEnvironment, seedDemo: Bool = false) {
        context = environment.persistence.mainContext
        repository = FinanceRepository(context: context)
        clock = environment.clock
        uuid = environment.uuidGenerator
        dataChanges = environment.dataChanges
        if seedDemo { try? seed() }
        reload()
    }

    func reload() {
        do {
            currencies = try repository.currencies()
            if !currencies.contains(currencyCode) { currencyCode = currencies.first ?? "EUR" }
            snapshot = try repository.snapshot(period: period, currencyCode: currencyCode, now: clock.now())
            error = nil
        } catch { self.error = AppErrorMapper.map(error, operation: "finance.reload") }
    }

    func selectPeriod(_ value: FinancePeriod) { period = value; reload() }
    func selectCurrency(_ value: String) { currencyCode = value; reload() }

    private func seed() throws {
        guard try repository.ledgerEvents().isEmpty,
              let client = try context.fetch(FetchDescriptor<ClientRecord>()).first else { return }
        let packages = PackageLedgerRepository(context: context, uuid: uuid, clock: clock)
        let calendar = Calendar.current
        for (index, sale) in [("Starter", Decimal(75)), ("Everyday", Decimal(120)), ("Coaching", Decimal(180))].enumerated() {
            let date = calendar.date(byAdding: .month, value: -index, to: clock.now()) ?? clock.now()
            _ = try packages.createPackage(.init(
                dogID: Self.unassignedDogID,
                name: sale.0,
                unitType: .session,
                initialUnits: 5 + Decimal(index),
                purchasedAt: date,
                expiresAt: nil,
                paymentStatus: .paid,
                price: sale.1,
                currencyCode: "EUR",
                clientID: client.id
            ))
        }
        dataChanges.notify()
    }

    private static let unassignedDogID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
}

struct FinanceRootView: View {
    @State private var model: FinanceFeatureModel
    private let environment: AppEnvironment

    init(environment: AppEnvironment, seedDemo: Bool = false) {
        self.environment = environment
        _model = State(initialValue: FinanceFeatureModel(environment: environment, seedDemo: seedDemo))
    }

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    filters(model: model)
                    if let snapshot = model.snapshot {
                        if snapshot.transactions.isEmpty {
                            ContentUnavailableView("No revenue in this period", systemImage: "chart.bar.xaxis", description: Text("Package sales appear here as soon as they are recorded."))
                        } else {
                            FinanceSummaryGrid(snapshot: snapshot)
                            FinanceTimelineCard(snapshot: snapshot)
                            FinancePackageCard(snapshot: snapshot)
                            FinanceClientCard(snapshot: snapshot)
                            FinanceTransactionTable(snapshot: snapshot)
                            FinanceExportButton(snapshot: snapshot)
                        }
                    }
                }
                .frame(maxWidth: 1_000, alignment: .leading)
                .padding()
            }
            .navigationTitle("Finance")
            .accessibilityIdentifier("financeRoot")
            .onAppear { model.reload() }
            .onChange(of: environment.dataChanges.revision) { model.reload() }
            .alert("Could not load finance data", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
                Button("OK") { model.error = nil }
            } message: { Text(model.error?.userMessage ?? "") }
        }
    }

    private func filters(model: FinanceFeatureModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Period", selection: Binding(get: { model.period }, set: { value in model.selectPeriod(value) })) {
                Text("Month").tag(FinancePeriod.month)
                Text("Quarter").tag(FinancePeriod.quarter)
                Text("Year").tag(FinancePeriod.year)
                Text("All").tag(FinancePeriod.all)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("financePeriodPicker")
            if model.currencies.count > 1 {
                Picker("Currency", selection: Binding(get: { model.currencyCode }, set: { value in model.selectCurrency(value) })) {
                    ForEach(model.currencies, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)
            }
        }
    }
}

private struct FinanceClientCard: View {
    let snapshot: FinanceSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top clients").font(.headline)
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                GridRow {
                    Text("Client").fontWeight(.semibold)
                    Text("Sales").fontWeight(.semibold)
                    Text("Revenue").fontWeight(.semibold)
                }
                Divider().gridCellColumns(3)
                ForEach(snapshot.clients.prefix(10)) { client in
                    GridRow {
                        Text(client.name)
                        Text(client.salesCount, format: .number)
                        Text(client.revenue, format: .currency(code: snapshot.currencyCode))
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground), in: .rect(cornerRadius: 14))
        .accessibilityIdentifier("financeTopClients")
    }
}

private struct FinanceSummaryGrid: View {
    let snapshot: FinanceSnapshot
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
            FinanceMetricCard(title: "Revenue", value: snapshot.totalRevenue.formatted(.currency(code: snapshot.currencyCode)), systemImage: "eurosign.circle")
            FinanceMetricCard(title: "Package sales", value: snapshot.salesCount.formatted(), systemImage: "ticket")
            FinanceMetricCard(title: "Average sale", value: snapshot.averageSale.formatted(.currency(code: snapshot.currencyCode)), systemImage: "chart.line.uptrend.xyaxis")
        }
        .accessibilityIdentifier("financeSummary")
    }
}

private struct FinanceMetricCard: View {
    let title: LocalizedStringResource
    let value: String
    let systemImage: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage).font(.subheadline).foregroundStyle(.secondary)
            Text(value).font(.title2.bold()).minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary, in: .rect(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }
}

private struct FinanceTimelineCard: View {
    let snapshot: FinanceSnapshot
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Revenue over time").font(.headline)
            Chart(snapshot.timeline) { point in
                BarMark(
                    x: .value("Date", point.start),
                    y: .value("Revenue", NSDecimalNumber(decimal: point.revenue).doubleValue)
                )
                .foregroundStyle(by: .value("Currency", snapshot.currencyCode))
                .accessibilityLabel(point.start.formatted(date: snapshot.period == .month ? .abbreviated : .numeric, time: .omitted))
                .accessibilityValue(point.revenue.formatted(.currency(code: snapshot.currencyCode)))
            }
            .chartLegend(.hidden)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: snapshot.period == .month ? 6 : 8)) {
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel()
                }
            }
            .frame(height: 240)
            .accessibilityLabel("Revenue over time")
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground), in: .rect(cornerRadius: 14))
        .accessibilityIdentifier("financeRevenueChart")
    }
}

private struct FinancePackageCard: View {
    let snapshot: FinanceSnapshot
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Revenue by package").font(.headline)
            Chart(snapshot.packages) { package in
                BarMark(
                    x: .value("Revenue", NSDecimalNumber(decimal: package.revenue).doubleValue),
                    y: .value("Package", package.name)
                )
                .foregroundStyle(by: .value("Package", package.name))
                .accessibilityLabel(package.name)
                .accessibilityValue("\(package.salesCount) sales, \(package.revenue.formatted(.currency(code: snapshot.currencyCode)))")
            }
            .chartLegend(.hidden)
            .frame(height: max(160, CGFloat(snapshot.packages.count) * 42))
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow { Text("Package").fontWeight(.semibold); Text("Sales").fontWeight(.semibold); Text("Revenue").fontWeight(.semibold) }
                Divider().gridCellColumns(3)
                ForEach(snapshot.packages) { package in
                    GridRow {
                        Text(package.name)
                        Text(package.salesCount, format: .number)
                        Text(package.revenue, format: .currency(code: snapshot.currencyCode))
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground), in: .rect(cornerRadius: 14))
        .accessibilityIdentifier("financePackageBreakdown")
    }
}

private struct FinanceExportButton: View {
    let snapshot: FinanceSnapshot
    @State private var exportURL: URL?
    var body: some View {
        Group {
            if let exportURL {
                ShareLink(item: exportURL) {
                    Label("Export CSV", systemImage: "square.and.arrow.up")
                }
            } else {
                Button("Export CSV", systemImage: "square.and.arrow.up") {}
                    .disabled(true)
            }
        }
        .buttonStyle(.borderedProminent)
        .accessibilityIdentifier("financeExportButton")
        .task {
            exportURL = try? FinanceCSVExporter.temporaryURL(for: snapshot)
        }
    }
}

private struct FinanceTransactionTable: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let snapshot: FinanceSnapshot
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sales ledger").font(.headline)
            Table(snapshot.transactions) {
                TableColumn("Date") { event in
                    VStack(alignment: .leading) {
                        Text(event.date, format: .dateTime.year().month().day())
                        if horizontalSizeClass == .compact {
                            Text(event.clientName).font(.caption).foregroundStyle(.secondary)
                            Text(event.packageTemplateName ?? event.packageName).font(.caption).foregroundStyle(.secondary)
                            Text(event.amount, format: .currency(code: event.currencyCode)).fontWeight(.semibold)
                        }
                    }
                }
                TableColumn("Client") { Text($0.clientName) }
                TableColumn("Package") { Text($0.packageTemplateName ?? $0.packageName) }
                TableColumn("Revenue") { Text($0.amount, format: .currency(code: $0.currencyCode)) }
            }
            .frame(height: min(480, max(180, CGFloat(snapshot.transactions.count) * 52 + 48)))
        }
        .accessibilityIdentifier("financeTransactionsTable")
    }
}
