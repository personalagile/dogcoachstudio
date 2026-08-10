import SwiftUI

struct ClientEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let model: PeopleFeatureModel
    let client: ClientSummary?
    @State private var draft: ClientDraft
    @State private var error: AppError?

    init(model: PeopleFeatureModel, client: ClientSummary?) {
        self.model = model
        self.client = client
        _draft = State(initialValue: ClientDraft(
            displayName: client?.displayName ?? "",
            email: client?.email,
            phone: client?.phone,
            addressStreet: client?.addressStreet,
            addressPostalCode: client?.addressPostalCode,
            addressCity: client?.addressCity,
            addressCountryCode: client?.addressCountryCode,
            privateNotes: client?.privateNotes
        ))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Contact") {
                    TextField("Name", text: $draft.displayName)
                        .textContentType(.name)
                        .accessibilityIdentifier("clientNameField")
                    TextField("Email", text: optionalBinding(\.email))
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                    TextField("Phone", text: optionalBinding(\.phone))
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                }
                Section("Address") {
                    TextField("Street", text: optionalBinding(\.addressStreet))
                    TextField("Postal code", text: optionalBinding(\.addressPostalCode))
                    TextField("City", text: optionalBinding(\.addressCity))
                    TextField("Country code", text: optionalBinding(\.addressCountryCode))
                        .textInputAutocapitalization(.characters)
                }
                Section("Private trainer notes") {
                    TextEditor(text: optionalBinding(\.privateNotes))
                        .frame(minHeight: 100)
                    Text("Private notes never enter client reports automatically.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(client == nil ? "New client" : "Edit client")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(draft.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("clientSaveButton")
                }
            }
            .alert("Could not save client", isPresented: errorBinding) { Button("OK") { } } message: {
                Text(error?.userMessage ?? "")
            }
        }
    }

    private func save() {
        do {
            if let client { try model.editClient(id: client.id, draft: draft) }
            else { try model.createClient(draft) }
            dismiss()
        } catch {
            self.error = AppErrorMapper.map(error, operation: "client.save")
        }
    }

    private func optionalBinding(_ keyPath: WritableKeyPath<ClientDraft, String?>) -> Binding<String> {
        Binding(
            get: { draft[keyPath: keyPath] ?? "" },
            set: { draft[keyPath: keyPath] = $0 }
        )
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { error != nil }, set: { if !$0 { error = nil } })
    }
}
struct DogEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let model: PeopleFeatureModel
    let dog: DogSummary?
    @State private var draft: DogDraft
    @State private var safetyFlagsText: String
    @State private var hasBirthDate: Bool
    @State private var error: AppError?

    init(model: PeopleFeatureModel, dog: DogSummary?) {
        self.model = model
        self.dog = dog
        _draft = State(initialValue: DogDraft(
            name: dog?.name ?? "",
            photoAssetID: nil,
            birthDate: dog?.birthDate,
            breedText: dog?.breedText,
            sexRawValue: dog?.sexRawValue,
            safetyFlagRawValues: dog?.safetyFlagRawValues ?? [],
            safetyPrivateNote: dog?.safetyPrivateNote
        ))
        _safetyFlagsText = State(initialValue: dog?.safetyFlagRawValues.joined(separator: ", ") ?? "")
        _hasBirthDate = State(initialValue: dog?.birthDate != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Dog") {
                    TextField("Name", text: $draft.name)
                        .accessibilityIdentifier("dogNameField")
                    TextField("Breed", text: optionalBinding(\.breedText))
                    TextField("Sex", text: optionalBinding(\.sexRawValue))
                    Toggle("Birth date known", isOn: $hasBirthDate)
                    if hasBirthDate {
                        DatePicker("Birth date", selection: birthDateBinding, displayedComponents: .date)
                    }
                }
                Section("Safety markers") {
                    TextField("Markers separated by commas", text: $safetyFlagsText, axis: .vertical)
                    TextEditor(text: optionalBinding(\.safetyPrivateNote))
                        .frame(minHeight: 90)
                    Text("Use factual markers only. The app does not create diagnoses.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(dog == nil ? "New dog" : "Edit dog")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("dogSaveButton")
                }
            }
            .alert("Could not save dog", isPresented: errorBinding) { Button("OK") { } } message: {
                Text(error?.userMessage ?? "")
            }
        }
    }

    private func save() {
        draft.birthDate = hasBirthDate ? (draft.birthDate ?? .now) : nil
        draft.safetyFlagRawValues = safetyFlagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        do {
            if let dog { try model.editDog(id: dog.id, draft: draft) }
            else { try model.createDog(draft) }
            dismiss()
        } catch {
            self.error = AppErrorMapper.map(error, operation: "dog.save")
        }
    }

    private func optionalBinding(_ keyPath: WritableKeyPath<DogDraft, String?>) -> Binding<String> {
        Binding(get: { draft[keyPath: keyPath] ?? "" }, set: { draft[keyPath: keyPath] = $0 })
    }

    private var birthDateBinding: Binding<Date> {
        Binding(get: { draft.birthDate ?? .now }, set: { draft.birthDate = $0 })
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { error != nil }, set: { if !$0 { error = nil } })
    }
}
