import Observation
import SwiftUI

struct RoleEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let model: PeopleFeatureModel
    let dog: DogSummary
    @State private var clientID: UUID?
    @State private var kind: ClientDogRoleKind = .owner
    @State private var primary = false

    var body: some View {
        NavigationStack {
            Form {
                Picker("Client", selection: $clientID) {
                    Text("Select a client").tag(UUID?.none)
                    ForEach(model.clients.filter { !$0.isArchived }) { Text($0.displayName).tag(Optional($0.id)) }
                }.accessibilityIdentifier("roleClientPicker")
                Picker("Role", selection: $kind) { ForEach(ClientDogRoleKind.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) } }
                Toggle("Primary contact", isOn: $primary)
            }
            .navigationTitle("Add contact")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let clientID else { return }
                        if model.perform({
                            try model.assignRole(clientID: clientID, dogID: dog.id, kind: kind, primary: primary)
                        }, operation: "role.save") { dismiss() }
                    }
                        .disabled(clientID == nil).accessibilityIdentifier("roleSaveButton")
                }
            }
        }
    }
}

struct ClientPackageEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let model: PeopleFeatureModel
    let client: ClientSummary
    @State private var templateID: UUID?
    @State private var error: AppError?

    var body: some View {
        let templates = model.packageTemplates()
        NavigationStack {
            Form {
                LabeledContent("Client", value: client.displayName)
                Picker("Package template", selection: $templateID) {
                    Text("Select").tag(UUID?.none)
                    ForEach(templates) { Text("\($0.name) · \($0.price.formatted(.currency(code: $0.currencyCode)))").tag(Optional($0.id)) }
                }
            }
            .navigationTitle("Sell package")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") {
                    guard let template = templates.first(where: { $0.id == templateID }) else { return }
                    do { try model.createPackage(clientID: client.id, template: template); dismiss() }
                    catch { self.error = AppErrorMapper.map(error, operation: "client.package.create") }
                }.disabled(templateID == nil).accessibilityIdentifier("clientPackageSaveButton") }
            }
            .alert("Could not save package", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") {} } message: { Text(error?.userMessage ?? "") }
        }
    }
}

@MainActor @Observable
final class IntakeEditorModel {
    var draft: IntakeDraft
    var error: AppError?
    private let autosave: IntakeDraftAutosave

    init(dogID: UUID, repository: any IntakeRepository, clock: any AppClock, uuidGenerator: any UUIDGenerating) {
        autosave = IntakeDraftAutosave(repository: repository)
        draft = (try? repository.drafts(for: dogID).first) ?? IntakeDraft(id: uuidGenerator.makeUUID(), dogID: dogID, occurredAt: clock.now())
    }
    func changed() { autosave.schedule(draft) }
    func save() -> Bool { do { try autosave.flush(); return true } catch { self.error = AppErrorMapper.map(error, operation: "intake.save"); return false } }
}

struct IntakeEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State var model: IntakeEditorModel

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            Form {
                Section("Client-facing intake") {
                    TextField("Reason for training", text: $model.draft.clientFacing.reason, axis: .vertical).accessibilityIdentifier("intakeReasonField")
                    TextField("Environment", text: $model.draft.clientFacing.environment, axis: .vertical)
                    TextField("History", text: $model.draft.clientFacing.history, axis: .vertical)
                    TextField("Known triggers", text: $model.draft.clientFacing.knownTriggers, axis: .vertical)
                    TextField("Previous training", text: $model.draft.clientFacing.previousTraining, axis: .vertical)
                    TextField("Health notes", text: $model.draft.clientFacing.healthNotes, axis: .vertical)
                    TextField("Desired outcome", text: $model.draft.clientFacing.desiredOutcome, axis: .vertical)
                }
                Section("Private trainer notes") {
                    TextEditor(text: $model.draft.privateFields.trainerNotes).frame(minHeight: 100).accessibilityIdentifier("intakePrivateNotesField")
                    Text("Never included in client-facing output automatically.").font(.footnote).foregroundStyle(.secondary)
                }
            }
            .onChange(of: model.draft) { model.changed() }
            .navigationTitle("Intake")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { _ = model.save(); dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { if model.save() { dismiss() } }.accessibilityIdentifier("intakeSaveButton") }
            }
            .accessibilityIdentifier("intakeEditor")
        }
    }
}

struct GoalEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let model: PeopleFeatureModel
    let dog: DogSummary
    let goal: TrainingGoal?
    @State private var title: String
    @State private var details: String
    @State private var status: TrainingGoalStatus
    @State private var error: AppError?

    init(model: PeopleFeatureModel, dog: DogSummary, goal: TrainingGoal?) {
        self.model = model; self.dog = dog; self.goal = goal
        _title = State(initialValue: goal?.title ?? "")
        _details = State(initialValue: goal?.targetDescription ?? "")
        _status = State(initialValue: goal?.status ?? .planned)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Goal", text: $title).accessibilityIdentifier("goalTitleField")
                TextField("Observable target", text: $details, axis: .vertical)
                Picker("Status", selection: $status) { ForEach(TrainingGoalStatus.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) } }
            }
            .navigationTitle("Training goal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var goal = goal ?? TrainingGoal(id: model.uuidGenerator.makeUUID(), dogID: dog.id, title: title, targetDescription: details, startedAt: model.clock.now())
                        goal.title = title; goal.targetDescription = details
                        goal.transition(to: status, at: model.clock.now())
                        do {
                            try model.saveGoal(goal)
                            dismiss()
                        } catch {
                            self.error = AppErrorMapper.map(error, operation: "training-goal.save")
                        }
                    }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("goalSaveButton")
                }
            }
            .alert("Could not save goal", isPresented: Binding(
                get: { error != nil },
                set: { if !$0 { error = nil } }
            )) { Button("OK") { } } message: { Text(error?.userMessage ?? "") }
        }
    }
}
