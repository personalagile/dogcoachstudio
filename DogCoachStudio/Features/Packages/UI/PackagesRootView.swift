import Observation
import SwiftData
import SwiftUI

@MainActor @Observable
final class PackagesFeatureModel {
    private let repository: PackageLedgerRepository
    private let context: ModelContext
    private let clock: any AppClock
    private let dataChanges: AppDataChanges
    var packages: [TrainingPackageSummary] = []
    var templates: [PackageTemplateSummary] = []
    var clients: [(id: UUID, name: String)] = []
    var error: AppError?

    init(environment: AppEnvironment, seedDemo: Bool = false) {
        context = environment.persistence.mainContext; clock = environment.clock; dataChanges = environment.dataChanges
        repository = .init(context: context, uuid: environment.uuidGenerator, clock: environment.clock)
        if seedDemo { try? seed() }; reload()
    }

    func reload() {
        do {
            packages = try repository.summaries(); templates = try repository.templates()
            clients = try context.fetch(FetchDescriptor<ClientRecord>()).filter { !$0.isArchived }.map { ($0.id, $0.displayName) }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        } catch { self.error = AppErrorMapper.map(error, operation: "packages.reload") }
    }

    func save(item: TrainingPackageSummary?, name: String, units: Decimal, clientID: UUID, templateID: UUID?, price: Decimal?, currencyCode: String, paymentStatus: PackagePaymentStatus) -> Bool {
        do {
            let draft = TrainingPackageDraft(dogID: item?.dogID ?? Self.unassignedDogID, name: name, unitType: .session, initialUnits: units, purchasedAt: clock.now(), expiresAt: item?.expiresAt, paymentStatus: paymentStatus, price: price, currencyCode: currencyCode, clientID: clientID, packageTemplateID: templateID)
            if let item { try repository.updatePackage(id: item.id, draft: draft) } else { _ = try repository.createPackage(draft) }
            reload(); dataChanges.notify(); return true
        } catch { self.error = AppErrorMapper.map(error, operation: "package.create"); return false }
    }

    func createTemplate(name: String, units: Decimal, price: Decimal, currencyCode: String) -> Bool {
        do { _ = try repository.createTemplate(.init(name: name, unitType: .session, units: units, price: price, currencyCode: currencyCode)); reload(); dataChanges.notify(); return true }
        catch { self.error = AppErrorMapper.map(error, operation: "package-template.create"); return false }
    }
    func updateTemplate(_ item: PackageTemplateSummary, name: String, units: Decimal, price: Decimal, currencyCode: String) -> Bool {
        do { try repository.updateTemplate(id: item.id, draft: .init(name: name, unitType: item.unitType, units: units, price: price, currencyCode: currencyCode)); reload(); dataChanges.notify(); return true }
        catch { self.error = AppErrorMapper.map(error, operation: "package-template.update"); return false }
    }

    func addUnit(packageID: UUID) { do { _ = try repository.adjust(packageID: packageID, units: 1, reason: "Manual adjustment"); reload(); dataChanges.notify() } catch { self.error = AppErrorMapper.map(error, operation: "package.adjust") } }
    func deletePackage(_ item: TrainingPackageSummary) { do { try repository.deletePackage(id: item.id); reload(); dataChanges.notify() } catch { self.error = AppErrorMapper.map(error, operation: "package.delete") } }
    func archiveTemplate(_ item: PackageTemplateSummary) { do { try repository.archiveTemplate(id: item.id); reload(); dataChanges.notify() } catch { self.error = AppErrorMapper.map(error, operation: "package-template.archive") } }

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
    private let environment: AppEnvironment
    init(environment: AppEnvironment, seedDemo: Bool = false) { self.environment = environment; _model = State(initialValue: .init(environment: environment, seedDemo: seedDemo)) }

    var body: some View {
        NavigationStack {
            List {
                Section("Sold packages") {
                    if model.packages.isEmpty { ContentUnavailableView("No packages", systemImage: "ticket") }
                    ForEach(model.packages) { item in
                        Button { sheet = .package(item) } label: { VStack(alignment: .leading, spacing: 4) {
                            HStack { Text(item.name).font(.headline); Spacer(); Text(item.status.title).font(.caption).foregroundStyle(.secondary) }
                            LabeledContent("Client", value: item.clientName.isEmpty ? String(localized: "Unknown client") : item.clientName)
                            if let templateName = item.packageTemplateName {
                                LabeledContent("Purchased package", value: templateName)
                            }
                            LabeledContent("Remaining credits") { Text(item.balance, format: .number) }
                            if let price = item.price { LabeledContent("Sale price") { Text(price, format: .currency(code: item.currencyCode ?? "EUR")) } }
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
                            LabeledContent("Included training credits") { Text(item.units, format: .number) }
                            LabeledContent("Standard price") { Text(item.price, format: .currency(code: item.currencyCode)) }
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
            .onAppear { model.reload() }
            .onChange(of: environment.dataChanges.revision) { model.reload() }
        }
    }
}

private extension PackageLifecycleStatus {
    var title: LocalizedStringResource {
        switch self {
        case .active: "Active"
        case .exhausted: "Used up"
        case .expired: "Expired"
        case .closed: "Closed"
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
    @State private var currencyCode: String
    @State private var paymentStatus: PackagePaymentStatus

    init(model: PackagesFeatureModel, item: TrainingPackageSummary?) {
        self.model = model; self.item = item
        _name = State(initialValue: item?.name ?? "")
        _units = State(initialValue: item?.initialUnits ?? 5)
        _price = State(initialValue: item?.price ?? 0)
        _clientID = State(initialValue: item?.clientID)
        _templateID = State(initialValue: item?.packageTemplateID)
        _currencyCode = State(initialValue: item?.currencyCode ?? "EUR")
        _paymentStatus = State(initialValue: item?.paymentStatus ?? .paid)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Record a package sold to a client. Its credits are reduced when an eligible attended session is completed.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("packageFormIntroduction")
                }
                Section {
                    Picker("Client", selection: $clientID) {
                        Text("Select a client").tag(UUID?.none)
                        ForEach(model.clients, id: \.id) { Text($0.name).tag(Optional($0.id)) }
                    }
                    .accessibilityIdentifier("packageClientPicker")
                    Picker("Start from template", selection: $templateID) {
                        Text("Enter manually").tag(UUID?.none)
                        ForEach(model.templates) { Text($0.name).tag(Optional($0.id)) }
                    }
                    .onChange(of: templateID) { _, value in
                        if let template = model.templates.first(where: { $0.id == value }) {
                            name = template.name; units = template.units; price = template.price; currencyCode = template.currencyCode
                        }
                    }
                    .accessibilityIdentifier("packageTemplatePicker")
                } header: {
                    Text("Assignment")
                } footer: {
                    Text("The client owns the package. A template optionally fills in the usual name, credits, price, and currency; you can still adjust this sale.")
                }
                Section("Package details") {
                    PackageInputField(title: "Package name", help: "Use the name shown on the client’s purchase, for example “10-session card”.", systemImage: "ticket", helpAccessibilityIdentifier: "packageNameHelp") {
                        TextField("Example: 10-session card", text: $name)
                            .textInputAutocapitalization(.sentences)
                            .accessibilityIdentifier("packageNameField")
                    }
                    PackageInputField(title: "Training credits", help: "The number of sessions included at the time of sale. Session completion deducts the configured number of credits.", systemImage: "number.circle", helpAccessibilityIdentifier: "packageUnitsHelp") {
                        TextField("Example: 10", value: $units, format: .number)
                            .keyboardType(.decimalPad)
                            .accessibilityIdentifier("packageUnitsField")
                    }
                }
                Section("Sale details") {
                    PackageInputField(title: "Sale price", help: "The total amount charged for this package, including zero for a complimentary package.", systemImage: "banknote", helpAccessibilityIdentifier: "packagePriceHelp") {
                        TextField("Example: 190", value: $price, format: .number.precision(.fractionLength(0...2)))
                            .keyboardType(.decimalPad)
                            .accessibilityIdentifier("packagePriceField")
                    }
                    Picker("Currency", selection: $currencyCode) {
                        ForEach(["EUR", "USD", "GBP", "CHF"], id: \.self) { Text($0).tag($0) }
                    }
                    .accessibilityIdentifier("packageCurrencyPicker")
                    Picker("Payment status", selection: $paymentStatus) {
                        Text("Paid").tag(PackagePaymentStatus.paid)
                        Text("Unpaid").tag(PackagePaymentStatus.unpaid)
                        Text("Refunded").tag(PackagePaymentStatus.refunded)
                        Text("Unknown").tag(PackagePaymentStatus.unknown)
                    }
                    .accessibilityIdentifier("packagePaymentStatusPicker")
                }
                if let client = model.clients.first(where: { $0.id == clientID }), !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Section("Sale preview") {
                        LabeledContent("Client", value: client.name)
                        LabeledContent("Package", value: name)
                        LabeledContent("Starting balance") { Text(units, format: .number) }
                        LabeledContent("Price") { Text(price, format: .currency(code: currencyCode)) }
                    }
                }
            }
            .navigationTitle(item == nil ? "New package" : "Edit package")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { if let clientID, model.save(item: item, name: name, units: units, clientID: clientID, templateID: templateID, price: price, currencyCode: currencyCode, paymentStatus: paymentStatus) { dismiss() } }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || clientID == nil || units <= 0 || price < 0).accessibilityIdentifier("packageSaveButton") }
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
    @State private var currencyCode: String
    init(model: PackagesFeatureModel, item: PackageTemplateSummary?) { self.model = model; self.item = item; _name = State(initialValue: item?.name ?? ""); _units = State(initialValue: item?.units ?? 5); _price = State(initialValue: item?.price ?? 0); _currencyCode = State(initialValue: item?.currencyCode ?? "EUR") }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Create a reusable offer for packages you sell regularly. A template is not a sale and is not assigned to a client.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("packageTemplateFormIntroduction")
                }
                Section("Offer") {
                    PackageInputField(title: "Template name", help: "A recognizable offer name, for example “Puppy course – 8 sessions”.", systemImage: "rectangle.stack", helpAccessibilityIdentifier: "packageTemplateNameHelp") {
                        TextField("Example: Puppy course – 8 sessions", text: $name)
                            .textInputAutocapitalization(.sentences)
                            .accessibilityIdentifier("packageTemplateNameField")
                    }
                    PackageInputField(title: "Included training credits", help: "The starting credit balance copied to every package sold from this template.", systemImage: "number.circle", helpAccessibilityIdentifier: "packageTemplateUnitsHelp") {
                        TextField("Example: 8", value: $units, format: .number)
                            .keyboardType(.decimalPad)
                            .accessibilityIdentifier("packageTemplateUnitsField")
                    }
                    PackageInputField(title: "Standard price", help: "The suggested total sale price. It can be changed for an individual sale.", systemImage: "banknote", helpAccessibilityIdentifier: "packageTemplatePriceHelp") {
                        TextField("Example: 160", value: $price, format: .number.precision(.fractionLength(0...2)))
                            .keyboardType(.decimalPad)
                            .accessibilityIdentifier("packageTemplatePriceField")
                    }
                    Picker("Currency", selection: $currencyCode) {
                        ForEach(["EUR", "USD", "GBP", "CHF"], id: \.self) { Text($0).tag($0) }
                    }
                    .accessibilityIdentifier("packageTemplateCurrencyPicker")
                }
                if !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Section("Template preview") {
                        LabeledContent("Offer", value: name)
                        LabeledContent("Starting balance") { Text(units, format: .number) }
                        LabeledContent("Standard price") { Text(price, format: .currency(code: currencyCode)) }
                    }
                }
            }
            .navigationTitle(item == nil ? "New package template" : "Edit package template")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { let saved = item.map { model.updateTemplate($0, name: name, units: units, price: price, currencyCode: currencyCode) } ?? model.createTemplate(name: name, units: units, price: price, currencyCode: currencyCode); if saved { dismiss() } }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || units <= 0 || price < 0).accessibilityIdentifier("packageTemplateSaveButton") }
            }
        }
    }
}

private struct PackageInputField<Content: View>: View {
    let title: LocalizedStringResource
    let help: LocalizedStringResource
    let systemImage: String
    let helpAccessibilityIdentifier: String
    let content: Content

    init(
        title: LocalizedStringResource,
        help: LocalizedStringResource,
        systemImage: String,
        helpAccessibilityIdentifier: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.help = help
        self.systemImage = systemImage
        self.helpAccessibilityIdentifier = helpAccessibilityIdentifier
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            content
                .textFieldStyle(.roundedBorder)
            Text(help)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(helpAccessibilityIdentifier)
        }
        .padding(.vertical, 3)
    }
}
