import Observation
import SwiftData
import SwiftUI

@MainActor @Observable
final class PackagesFeatureModel {
    private let repository: PackageLedgerRepository
    private let context: ModelContext
    private let clock: any AppClock
    var packages: [TrainingPackageSummary] = []
    var dogs: [(UUID, String)] = []
    var error: AppError?
    init(environment: AppEnvironment, seedDemo: Bool = false) {
        context = environment.persistence.mainContext; clock = environment.clock
        repository = .init(context: context, uuid: environment.uuidGenerator, clock: environment.clock)
        if seedDemo { try? seed() }; reload()
    }
    func reload() { do { packages = try repository.summaries(); dogs = try context.fetch(FetchDescriptor<DogRecord>()).map { ($0.id, $0.name) } } catch { self.error = AppErrorMapper.map(error, operation: "packages.reload") } }
    func create(name: String, units: Int, dogID: UUID) -> Bool { do { _ = try repository.createPackage(.init(dogID: dogID, name: name, unitType: .session, initialUnits: Decimal(units), purchasedAt: clock.now(), expiresAt: nil, paymentStatus: .paid, price: nil, currencyCode: nil)); reload(); return true } catch { self.error = AppErrorMapper.map(error, operation: "package.create"); return false } }
    func addUnit(packageID: UUID) { do { _ = try repository.adjust(packageID: packageID, units: 1, reason: "Manual adjustment"); reload() } catch { self.error = AppErrorMapper.map(error, operation: "package.adjust") } }
    private func seed() throws { guard try context.fetch(FetchDescriptor<TrainingPackageRecord>()).isEmpty, let dog = try context.fetch(FetchDescriptor<DogRecord>()).first else { return }; _ = try repository.createPackage(.init(dogID: dog.id, name: "Demo 5 sessions", unitType: .session, initialUnits: 5, purchasedAt: clock.now(), expiresAt: nil, paymentStatus: .paid, price: nil, currencyCode: nil)) }
}

struct PackagesRootView: View {
    @State private var model: PackagesFeatureModel
    @State private var showsAdd = false
    init(environment: AppEnvironment, seedDemo: Bool = false) { _model = State(initialValue: .init(environment: environment, seedDemo: seedDemo)) }
    var body: some View {
        NavigationStack {
            List(model.packages) { item in
                VStack(alignment: .leading) {
                    Text(item.name).font(.headline); Text(item.dogName)
                    HStack { Text("Balance: \(NSDecimalNumber(decimal: item.balance).stringValue)"); Spacer(); Text(item.status.rawValue.capitalized) }
                }
                .accessibilityElement(children: .combine).accessibilityIdentifier("packageRow")
                .swipeActions { Button("Add unit") { model.addUnit(packageID: item.id) }.tint(.green) }
            }
            .navigationTitle("Packages")
            .toolbar { Button("Add", systemImage: "plus") { showsAdd = true }.accessibilityIdentifier("packageAddButton") }
            .sheet(isPresented: $showsAdd) { PackageEditor(model: model) { showsAdd = false } }
            .accessibilityIdentifier("packagesRoot")
        }
    }
}

private struct PackageEditor: View {
    let model: PackagesFeatureModel; let dismiss: () -> Void
    @State private var name = ""; @State private var units = 5; @State private var dogID: UUID?
    var body: some View { NavigationStack { Form { TextField("Name", text: $name).accessibilityIdentifier("packageNameField"); Stepper("Units: \(units)", value: $units, in: 1...100); Picker("Dog", selection: $dogID) { Text("Select").tag(UUID?.none); ForEach(model.dogs, id: \.0) { Text($0.1).tag(Optional($0.0)) } }.accessibilityIdentifier("packageDogPicker") }.navigationTitle("New package").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: dismiss) }; ToolbarItem(placement: .confirmationAction) { Button("Save") { if let dogID, model.create(name: name, units: units, dogID: dogID) { dismiss() } }.disabled(name.isEmpty || dogID == nil).accessibilityIdentifier("packageSaveButton") } } } }
}
