import SwiftUI

struct PeopleRootView: View {
    enum Sheet: Identifiable {
        case addClient
        case editClient(ClientSummary)
        case addDog
        case editDog(DogSummary)
        case addRole(DogSummary)
        case intake(DogSummary)
        case goal(DogSummary)

        var id: String {
            switch self {
            case .addClient: "add-client"
            case .editClient(let client): "edit-client-\(client.id)"
            case .addDog: "add-dog"
            case .editDog(let dog): "edit-dog-\(dog.id)"
            case .addRole(let dog): "add-role-\(dog.id)"
            case .intake(let dog): "intake-\(dog.id)"
            case .goal(let dog): "goal-\(dog.id)"
            }
        }
    }

    @State private var model: PeopleFeatureModel
    @State private var presentedSheet: Sheet?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    init(environment: AppEnvironment) {
        _model = State(initialValue: PeopleFeatureModel(
            context: environment.persistence.mainContext,
            clock: environment.clock,
            uuidGenerator: environment.uuidGenerator
        ))
    }

    var body: some View {
        @Bindable var model = model
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: $model.selection) {
                Section("Clients") {
                    ForEach(model.clients) { client in
                        NavigationLink(value: PeopleSelection.client(client.id)) {
                            ClientRow(client: client)
                        }
                    }
                }
                Section("Dogs") {
                    ForEach(model.dogs) { dog in
                        NavigationLink(value: PeopleSelection.dog(dog.id)) {
                            DogRow(dog: dog)
                        }
                    }
                }
            }
            .overlay { emptyState }
            .navigationTitle("People & Dogs")
            .searchable(text: $model.searchText, prompt: "Search people and dogs")
            .onChange(of: model.searchText) { model.reload() }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Toggle("Show archived", isOn: $model.includeArchived)
                        .onChange(of: model.includeArchived) { model.reload() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu("Add", systemImage: "plus") {
                        Button("New client", systemImage: "person.badge.plus") { presentedSheet = .addClient }
                        Button("New dog", systemImage: "dog") { presentedSheet = .addDog }
                    }
                    .accessibilityIdentifier("peopleAddMenu")
                }
            }
            .accessibilityIdentifier("peopleMasterList")
        } detail: {
            detail
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(item: $presentedSheet, onDismiss: { model.refreshDetailContent() }) { sheet in
            switch sheet {
            case .addClient:
                ClientEditorView(model: model, client: nil)
            case .editClient(let client):
                ClientEditorView(model: model, client: client)
            case .addDog:
                DogEditorView(model: model, dog: nil)
            case .editDog(let dog):
                DogEditorView(model: model, dog: dog)
            case .addRole(let dog):
                RoleEditorView(model: model, dog: dog)
            case .intake(let dog):
                IntakeEditorView(model: IntakeEditorModel(
                    dogID: dog.id,
                    repository: model.intakeRepository,
                    clock: model.clock,
                    uuidGenerator: model.uuidGenerator
                ))
            case .goal(let dog):
                GoalEditorView(model: model, dog: dog)
            }
        }
        .alert("Could not load data", isPresented: errorPresented) {
            Button("Retry") { model.reload() }
        } message: {
            Text(model.error?.userMessage ?? "")
        }
        .accessibilityIdentifier("peopleAdaptiveNavigation")
    }

    @ViewBuilder
    private var detail: some View {
        switch model.selection {
        case .client(let id):
            if let client = model.clients.first(where: { $0.id == id }) {
                ClientDetailView(client: client, model: model) { presentedSheet = $0 }
            } else {
                selectionPlaceholder
            }
        case .dog(let id):
            if let dog = model.dogs.first(where: { $0.id == id }) {
                DogFileView(dog: dog, model: model) { presentedSheet = $0 }
            } else {
                selectionPlaceholder
            }
        case nil:
            selectionPlaceholder
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if model.clients.isEmpty && model.dogs.isEmpty {
            if model.searchText.isEmpty {
                ContentUnavailableView(
                    "No people or dogs",
                    systemImage: "person.2",
                    description: Text("Add a client or dog to start a local record.")
                )
            } else {
                ContentUnavailableView.search(text: model.searchText)
            }
        }
    }

    private var selectionPlaceholder: some View {
        ContentUnavailableView(
            "Select a person or dog",
            systemImage: "sidebar.left",
            description: Text("Details stay available here while you browse on iPad.")
        )
    }

    private var errorPresented: Binding<Bool> {
        Binding(
            get: { model.error != nil },
            set: { if !$0 { model.error = nil } }
        )
    }
}

private struct ClientRow: View {
    let client: ClientSummary

    var body: some View {
        Label {
            VStack(alignment: .leading) {
                Text(client.displayName)
                if client.isArchived { Text("Archived").font(.caption).foregroundStyle(.secondary) }
            }
        } icon: {
            Image(systemName: client.isArchived ? "person.crop.circle.badge.xmark" : "person.crop.circle")
        }
        .accessibilityElement(children: .combine)
    }
}

private struct DogRow: View {
    let dog: DogSummary

    var body: some View {
        Label {
            VStack(alignment: .leading) {
                Text(dog.name)
                Text(dog.breedText ?? "Breed not recorded")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: dog.isArchived ? "dog.circle.fill" : "dog")
        }
        .accessibilityElement(children: .combine)
    }
}
