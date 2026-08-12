import PhotosUI
import Photos
import SwiftUI
import UIKit

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
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showsPhotoPicker = false
    @State private var showsPhotoPermissionAlert = false
    @State private var showsCamera = false
    private let originalPhotoAssetID: String?

    init(model: PeopleFeatureModel, dog: DogSummary?) {
        self.model = model
        self.dog = dog
        originalPhotoAssetID = dog?.photoAssetID
        _draft = State(initialValue: DogDraft(
            name: dog?.name ?? "",
            photoAssetID: dog?.photoAssetID,
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
                    HStack {
                        Spacer()
                        DogPhotoView(assetID: draft.photoAssetID, size: 132)
                        Spacer()
                    }
                    Button {
                        requestPhotoAccess()
                    } label: {
                        Label("Choose photo", systemImage: "photo.on.rectangle")
                    }
                    .accessibilityIdentifier("dogPhotoPicker")
                    Button("Take photo", systemImage: "camera") { showsCamera = true }
                        .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
                        .accessibilityIdentifier("dogCameraButton")
                    if draft.photoAssetID != nil {
                        Button("Remove photo", role: .destructive) { removePhoto() }
                    }
                    TextField("Name", text: $draft.name)
                        .accessibilityIdentifier("dogNameField")
                    TextField("Breed", text: optionalBinding(\.breedText))
                    Picker("Sex", selection: optionalBinding(\.sexRawValue)) {
                        Text("Unknown").tag("")
                        Text("Male").tag("male")
                        Text("Female").tag("female")
                    }
                    .accessibilityIdentifier("dogSexPicker")
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
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { cancel() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("dogSaveButton")
                }
            }
            .alert("Could not save dog", isPresented: errorBinding) { Button("OK") { } } message: {
                Text(error?.userMessage ?? "")
            }
            .onChange(of: selectedPhoto) { _, item in
                guard let item else { return }
                Task { await importPhoto(item) }
            }
            .photosPicker(isPresented: $showsPhotoPicker, selection: $selectedPhoto, matching: .images)
            .sheet(isPresented: $showsCamera) {
                CameraCaptureView { image in
                    showsCamera = false
                    storePhoto(image.jpegData(compressionQuality: 0.82))
                }
                .ignoresSafeArea()
            }
            .alert("Photo access needed", isPresented: $showsPhotoPermissionAlert) {
                Button("Open Settings") {
                    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Allow photo access in Settings to select a dog photo.")
            }
            .interactiveDismissDisabled()
        }
    }

    private func requestPhotoAccess() {
        Task {
            let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            switch status {
            case .authorized, .limited:
                showsPhotoPicker = true
            case .denied, .restricted:
                showsPhotoPermissionAlert = true
            case .notDetermined:
                break
            @unknown default:
                showsPhotoPermissionAlert = true
            }
        }
    }

    private func importPhoto(_ item: PhotosPickerItem) async {
        do {
            storePhoto(try await item.loadTransferable(type: Data.self))
        } catch {
            self.error = AppErrorMapper.map(error, operation: "dog.photo.import")
        }
    }

    private func storePhoto(_ data: Data?) {
        guard let data else { return }
        do {
            let oldID = draft.photoAssetID
            draft.photoAssetID = try DogPhotoStore.save(data)
            if let oldID, oldID != originalPhotoAssetID { DogPhotoStore.remove(oldID) }
        } catch {
            self.error = AppErrorMapper.map(error, operation: "dog.photo.save")
        }
    }

    private func removePhoto() {
        if let id = draft.photoAssetID, id != originalPhotoAssetID { DogPhotoStore.remove(id) }
        draft.photoAssetID = nil
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
            if let originalPhotoAssetID, originalPhotoAssetID != draft.photoAssetID {
                DogPhotoStore.remove(originalPhotoAssetID)
            }
            dismiss()
        } catch {
            self.error = AppErrorMapper.map(error, operation: "dog.save")
        }
    }

    private func cancel() {
        if let pendingID = draft.photoAssetID, pendingID != originalPhotoAssetID {
            DogPhotoStore.remove(pendingID)
        }
        dismiss()
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
