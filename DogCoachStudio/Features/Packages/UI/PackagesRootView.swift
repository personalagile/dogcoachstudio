import Observation
import SwiftData
import SwiftUI

@MainActor @Observable
final class PackagesFeatureModel {
    private let repository: PackageLedgerRepository
    private let context: ModelContext
    private let clock: any AppClock
    var packages: [TrainingPackageSummary] = []
    var templates: [PackageTemplateSummary] = []
    var clients: [(id: UUID, name: String)] = []
    var error: AppError?

    init(environment: AppEnvironment, seedDemo: Bool = false) {
        context = environment.persistence.mainContext; clock = environment.clock
        repository = .init(context: context, uuid: environment.uuidGenerator, clock: environment.clock)
        if seedDemo { try? seed() }; reload()
    }

    func reload() {
        do {
            packages = try repository.summaries(); templates = try repository.templates()
            clients = try context.fetch(FetchDescriptor<ClientRecord>()).filter { !$0.isArchived }.map { ($0.id, $0.displayName) }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        } catch { self.error = AppErrorMapper.map(error, operation: "packages.reload") }
    }

    func save(item: TrainingPackageSummary?, name: String, units: Decimal, clientID: UUID, templateID: UUID?, price: Decimal?, currencyCode: String) -> Bool {
        do {
            let draft = TrainingPackageDraft(dogID: item?.dogID ?? Self.unassignedDogID, name: name, unitType: .session, initialUnits: units, purchasedAt: clock.now(), expiresAt: item?.expiresAt, paymentStatus: item?.paymentStatus ?? .paid, price: price, currencyCode: currencyCode, clientID: clientID, packageTemplateID: templateID)
            if let item { try repository.updatePackage(id: item.id, draft: draft) } else { _ = try repository.createPackage(draft) }
            reload(); return true
        } catch { self.error = AppErrorMapper.map(error, operation: "package.create"); return false }
    }

    func createTemplate(name: String, units: Decimal, price: Decimal, currencyCode: String) -> Bool {
        do { _ = try repository.createTemplate(.init(name: name, unitType: .session, units: units, price: price, currencyCode: currencyCode)); reload(); return true }
        catch { self.error = AppErrorMapper.map(error, operation: "package-template.create"); return false }
    }
    func updateTemplate(_ item: PackageTemplateSummary, name: String, units: Decimal, price: Decimal, currencyCode: String) -> Bool {
        do { try repository.updateTemplate(id: item.id, draft: .init(name: name, unitType: item.unitType, units: units, price: price, currencyCode: currencyCode)); reload(); return true }
        catch { self.error = AppErrorMapper.map(error, operation: "package-template.update"); return false }
    }

    func addUnit(packageID: UUID) { do { _ = try repository.adjust(packageID: packageID, units: 1, reason: "Manual adjustment"); reload() } catch { self.error = AppErrorMapper.map(error, operation: "package.adjust") } }
    func deletePackage(_ item: TrainingPackageSummary) { do { try repository.deletePackage(id: item.id); reload() } catch { self.error = AppErrorMapper.map(error, operation: "package.delete") } }
    func archiveTemplate(_ item: PackageTemplateSummary) { do { try repository.archiveTemplate(id: item.id); reload() } catch { self.error = AppErrorMapper.map(error, operation: "package-template.archive") } }

    private func seed() throws {
        guard try context.fetch(FetchDescriptor<TrainingPackageRecord>()).isEmpty,
              let client = try context.fetch(FetchDescriptor<ClientRecord>()).first else { return }
        _ = try repository.createPackage(.init(dogID: Self.unassignedDogID, name: "Demo 5 sessions", unitType: .session, initialUnits: 5, purchasedAt: clock.now(), expiresAt: nil, paymentStatus: .paid, price: 75, currencyCode: "EUR", clientID: client.id))
    }

    private static let unassignedDogID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
}

struct PackagesRootView: View {
    enum Sheet: Identifiable { case package(TrainingPackageSummary?), template(PackageTemplateSummary?); var id: String { switch self { case .package(let item): "package-\(item?.id.uuidString ?? "new")"; case .template(let item): "template-\(item?.id.uuidString ?? "new")" } } }
    @State private var model: PackagesFeatureModel
    @State private var sheet: Sheet?
    init(environment: AppEnvironment, seedDemo: Bool = false) { _model = State(initialValue: .init(environment: environment, seedDemo: seedDemo)) }

    var body: some View {
        NavigationStack {
            List {
                Section("Sold packages") {
                    if model.packages.isEmpty { ContentUnavailableView("No packages", systemImage: "ticket") }
                    ForEach(model.packages) { item in
                        Button { sheet = .package(item) } label: { VStack(alignment: .leading, spacing: 4) {
                            HStack { Text(item.name).font(.headline); Spacer(); Text(item.status.rawValue.capitalized) }
                            Text(item.clientName.isEmpty ? String(localized: "Unknown client") : item.clientName)
                            HStack {
                                Text("Balance: \(NSDecimalNumber(decimal: item.balance).stringValue)")
                                Spacer()
                                if let price = item.price { Text(price, format: .currency(code: item.currencyCode ?? "EUR")) }
                            }
                        } }.buttonStyle(.plain)
                        .accessibilityElement(children: .combine).accessibilityIdentifier("packageRow")
                        .swipeActions {
                            Button("Delete", role: .destructive) { model.deletePackage(item) }
                            Button("Add unit") { model.addUnit(packageID: item.id) }.tint(.green)
                        }
                    }
                }
                Section("Package templates") {
                    ForEach(model.templates) { item in
                        Button { sheet = .template(item) } label: { VStack(alignment: .leading, spacing: 4) {
                            Text(item.name).font(.headline)
                            Text("\(NSDecimalNumber(decimal: item.units).stringValue) units · \(item.price.formatted(.currency(code: item.currencyCode)))")
                            Text("\(item.salesCount) sales").font(.caption).foregroundStyle(.secondary)
                        } }.buttonStyle(.plain)
                        .accessibilityIdentifier("packageTemplateRow")
                        .swipeActions { Button("Archive", role: .destructive) { model.archiveTemplate(item) } }
                    }
                }
            }
            .navigationTitle("Packages")
            .toolbar { Menu("Add", systemImage: "plus") { Button("Sell package") { sheet = .package(nil) }; Button("Package template") { sheet = .template(nil) } }.accessibilityIdentifier("packageAddButton") }
            .sheet(item: $sheet) { value in switch value { case .package(let item): PackageEditor(model: model, item: item); case .template(let item): PackageTemplateEditor(model: model, item: item) } }
            .alert("Could not update packages", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) { Button("OK") {} } message: { Text(model.error?.userMessage ?? "") }
            .accessibilityIdentifier("packagesRoot")
        }
    }
}

private struct PackageEditor: View {
    @Environment(\.dismiss) private var dismiss
    let model: PackagesFeatureModel
    let item: TrainingPackageSummary?
    @State private var name: String
    @State private var units: Decimal
    @State private var price: Decimal
    @State private var clientID: UUID?
    @State private var templateID: UUID?

    init(model: PackagesFeatureModel, item: TrainingPackageSummary?) {
        self.model = model; self.item = item
        _name = State(initialValue: item?.name ?? "")
        _units = State(initialValue: item?.initialUnits ?? 5)
        _price = State(initialValue: item?.price ?? 0)
        _clientID = State(initialValue: item?.clientID)
        _templateID = State(initialValue: item?.packageTemplateID)
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Client", selection: $clientID) { Text("Select").tag(UUID?.none); ForEach(model.clients, id: \.id) { Text($0.name).tag(Optional($0.id)) } }.accessibilityIdentifier("packageClientPicker")
                Picker("Package template", selection: $templateID) { Text("No template").tag(UUID?.none); ForEach(model.templates) { Text($0.name).tag(Optional($0.id)) } }
                    .onChange(of: templateID) { _, value in if let item = model.templates.first(where: { $0.id == value }) { name = item.name; units = item.units; price = item.price } }
                TextField("Name", text: $name).accessibilityIdentifier("packageNameField")
                TextField("Units", value: $units, format: .number).keyboardType(.decimalPad).accessibilityIdentifier("packageUnitsField")
                TextField("Price", value: $price, format: .number).keyboardType(.decimalPad).accessibilityIdentifier("packagePriceField")
            }
            .navigationTitle(item == nil ? "New package" : "Edit package")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { if let clientID, model.save(item: item, name: name, units: units, clientID: clientID, templateID: templateID, price: price, currencyCode: item?.currencyCode ?? "EUR") { dismiss() } }.disabled(name.isEmpty || clientID == nil || units <= 0).accessibilityIdentifier("packageSaveButton") }
            }
        }
    }
}

private struct PackageTemplateEditor: View {
    @Environment(\.dismiss) private var dismiss
    let model: PackagesFeatureModel
    let item: PackageTemplateSummary?
    @State private var name: String
    @State private var units: Decimal
    @State private var price: Decimal
    init(model: PackagesFeatureModel, item: PackageTemplateSummary?) { self.model = model; self.item = item; _name = State(initialValue: item?.name ?? ""); _units = State(initialValue: item?.units ?? 5); _price = State(initialValue: item?.price ?? 0) }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name).accessibilityIdentifier("packageTemplateNameField")
                TextField("Units", value: $units, format: .number).keyboardType(.decimalPad).accessibilityIdentifier("packageTemplateUnitsField")
                TextField("Price", value: $price, format: .number).keyboardType(.decimalPad).accessibilityIdentifier("packageTemplatePriceField")
            }
            .navigationTitle(item == nil ? "New package template" : "Edit package template")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { let saved = item.map { model.updateTemplate($0, name: name, units: units, price: price, currencyCode: "EUR") } ?? model.createTemplate(name: name, units: units, price: price, currencyCode: "EUR"); if saved { dismiss() } }.disabled(name.isEmpty || units <= 0 || price < 0).accessibilityIdentifier("packageTemplateSaveButton") }
            }
        }
    }
}
