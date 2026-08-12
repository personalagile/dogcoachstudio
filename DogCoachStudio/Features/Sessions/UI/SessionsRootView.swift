import Observation
import SwiftData
import SwiftUI

@MainActor @Observable
final class SessionsFeatureModel {
    private let context: ModelContext
    private let repository: SwiftDataScheduledSessionRepository
    private let completion: SessionCompletionService
    private let clock: any AppClock
    private let uuid: any UUIDGenerating
    var sessions: [ScheduledSessionSummary] = []
    var dogs: [(id: UUID, name: String)] = []
    var templates: [TrainingTemplateSummary] = []
    var selectedSessionID: UUID?
    var attendance: [UUID: SessionAttendanceStatus] = [:]
    var defaultOutcome: ExerciseOutcome = .independent
    var preview: CompletionPreview?
    var completed: PersistentCompletionResult?
    var error: AppError?

    init(environment: AppEnvironment, seedDemo: Bool = false) {
        context = environment.persistence.mainContext
        repository = .init(context: context, uuid: environment.uuidGenerator)
        completion = .init(context: context, clock: environment.clock, uuid: environment.uuidGenerator)
        clock = environment.clock
        uuid = environment.uuidGenerator
        if seedDemo { try? seedUITestDemo() }
        reload()
    }

    func reload() {
        do {
            sessions = try repository.list()
            dogs = try context.fetch(FetchDescriptor<DogRecord>()).filter { !$0.isArchived }.map { ($0.id, $0.name) }
            templates = try SwiftDataTrainingTemplateRepository(context: context, uuid: uuid).summaries().filter(\.isPublished)
        } catch { self.error = AppErrorMapper.map(error, operation: "sessions.reload") }
    }

    func create(title: String, duration: Int, kind: ScheduledSessionKind, templateVersionID: UUID?, dogIDs: [UUID]) -> Bool {
        do {
            _ = try repository.create(.init(title: title, startAt: clock.now(), durationMinutes: duration, locationText: nil, kind: kind, templateVersionID: templateVersionID, dogIDs: dogIDs))
            reload(); return true
        } catch { self.error = AppErrorMapper.map(error, operation: "session.create"); return false }
    }

    func select(_ id: UUID) {
        do {
            guard let session = try repository.session(id: id) else { return }
            var status = ScheduledSessionStatus(rawValue: session.statusRawValue) ?? .draft
            if status == .draft { try repository.transition(sessionID: id, to: .scheduled); status = .scheduled }
            if status == .scheduled { try repository.transition(sessionID: id, to: .inProgress) }
            selectedSessionID = id
            attendance = Dictionary(uniqueKeysWithValues: (session.bookings ?? []).map { ($0.id, .attended) })
            preview = nil; completed = nil; reload()
        } catch { self.error = AppErrorMapper.map(error, operation: "session.start") }
    }

    func makePreview() {
        guard let request = request() else { return }
        do { preview = try completion.preview(request) }
        catch { self.error = AppErrorMapper.map(error, operation: "session.preview") }
    }

    func complete() {
        guard let request = request() else { return }
        do { completed = try completion.complete(request); reload() }
        catch { self.error = AppErrorMapper.map(error, operation: "session.complete") }
    }

    func correct(reason: String) -> Bool {
        guard let completed else { return false }
        do {
            self.completed = try completion.correct(.init(originalCompletedSessionID: completed.completedSessionID, completionToken: uuid.makeUUID(), reason: reason, changes: []))
            reload(); return true
        } catch { self.error = AppErrorMapper.map(error, operation: "session.correct"); return false }
    }

    func bookings() -> [(id: UUID, dogName: String)] {
        guard let selectedSessionID,
              let session = try? repository.session(id: selectedSessionID) else { return [] }
        return (session.bookings ?? []).map { ($0.id, $0.dog?.name ?? String(localized: "Dog")) }
    }

    private var completionToken: UUID?
    private func request() -> PersistentCompletionRequest? {
        guard let selectedSessionID else { return nil }
        let token = completionToken ?? uuid.makeUUID()
        completionToken = token
        return .init(sessionID: selectedSessionID, completionToken: token, attendanceByBookingID: attendance, defaultOutcome: defaultOutcome, overrides: [])
    }

    private func seedUITestDemo() throws {
        if let url = Bundle.main.url(forResource: "foundation-v1", withExtension: "json") {
            _ = try ContentPackImporter(context: context, uuid: uuid).importPack(data: Data(contentsOf: url))
        }
        guard try context.fetch(FetchDescriptor<ScheduledSessionRecord>()).isEmpty,
              let dog = try context.fetch(FetchDescriptor<DogRecord>()).first,
              let template = try SwiftDataTrainingTemplateRepository(context: context, uuid: uuid).summaries().first else { return }
        let package = TrainingPackageRecord(id: uuid.makeUUID(), dogID: dog.id, name: "Demo package", initialUnits: 5, purchasedAt: clock.now())
        package.dog = dog; context.insert(package); try context.save()
        _ = try repository.create(.init(title: "Phase 4 group session", startAt: clock.now(), durationMinutes: 45, locationText: nil, kind: .group, templateVersionID: template.versionID, dogIDs: [dog.id]))
    }
}

struct SessionsRootView: View {
    @State private var model: SessionsFeatureModel
    @State private var showsCreate = false
    init(environment: AppEnvironment, seedDemo: Bool = false) { _model = State(initialValue: SessionsFeatureModel(environment: environment, seedDemo: seedDemo)) }

    var body: some View {
        NavigationStack {
            List(model.sessions) { session in
                Button { model.select(session.id) } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.title).font(.headline)
                        Text("\(session.bookingCount) bookings · \(session.durationMinutes) min")
                        if session.hasOverlap { Label("Overlaps another session", systemImage: "exclamationmark.triangle").foregroundStyle(.orange) }
                    }
                }
                .accessibilityIdentifier("scheduledSessionRow")
            }
            .navigationTitle("Sessions")
            .toolbar { Button("Add", systemImage: "plus") { showsCreate = true }.accessibilityIdentifier("sessionAddButton") }
            .sheet(isPresented: $showsCreate) { SessionEditorView(model: model) { showsCreate = false } }
            .navigationDestination(isPresented: Binding(get: { model.selectedSessionID != nil }, set: { if !$0 { model.selectedSessionID = nil } })) {
                SessionCompletionReviewView(model: model)
            }
            .accessibilityIdentifier("sessionsRoot")
        }
    }
}

private struct SessionEditorView: View {
    let model: SessionsFeatureModel
    let dismiss: () -> Void
    @State private var title = ""
    @State private var duration = 45
    @State private var kind = ScheduledSessionKind.group
    @State private var templateVersionID: UUID?
    @State private var dogIDs: Set<UUID> = []

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title).accessibilityIdentifier("sessionTitleField")
                Stepper("Duration: \(duration) min", value: $duration, in: 5...240, step: 5)
                Picker("Kind", selection: $kind) { ForEach(ScheduledSessionKind.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) } }
                Picker("Template", selection: $templateVersionID) { Text("No template").tag(UUID?.none); ForEach(model.templates) { Text($0.title).tag(Optional($0.versionID)) } }
                Section("Dogs") { ForEach(model.dogs, id: \.id) { dog in Toggle(dog.name, isOn: Binding(get: { dogIDs.contains(dog.id) }, set: { if $0 { dogIDs.insert(dog.id) } else { dogIDs.remove(dog.id) } })) } }
            }
            .navigationTitle("New session")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: dismiss) }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { if model.create(title: title, duration: duration, kind: kind, templateVersionID: templateVersionID, dogIDs: Array(dogIDs)) { dismiss() } }.disabled(title.isEmpty).accessibilityIdentifier("sessionSaveButton") }
            }
        }
    }
}

private struct SessionCompletionReviewView: View {
    let model: SessionsFeatureModel
    @State private var correctionReason = ""
    @State private var showsCorrection = false

    var body: some View {
        @Bindable var model = model
        Form {
            Section("Attendance") {
                ForEach(model.bookings(), id: \.id) { booking in
                    Picker(booking.dogName, selection: Binding(get: { model.attendance[booking.id] ?? .attended }, set: { model.attendance[booking.id] = $0; model.preview = nil })) {
                        ForEach(SessionAttendanceStatus.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .accessibilityIdentifier("attendancePicker")
                }
            }
            Section("Default outcome") { Picker("Outcome", selection: $model.defaultOutcome) { ForEach(ExerciseOutcome.allCases, id: \.self) { Text($0.rawValue).tag($0) } } }
            if let preview = model.preview {
                Section("Preview") {
                    Text("Completion preview").accessibilityIdentifier("completionPreview")
                    LabeledContent("Results", value: "\(preview.resultCount)")
                    LabeledContent("Reports", value: "\(preview.reportCount)")
                    LabeledContent("Package entries", value: "\(preview.packages.filter { $0.policy != .skip }.count)")
                    if preview.hasInsufficientBalance { Label("Insufficient package balance; completion remains available", systemImage: "exclamationmark.triangle").foregroundStyle(.orange).accessibilityIdentifier("insufficientBalanceWarning") }
                    Button("Complete session") { model.complete() }.accessibilityIdentifier("persistentCompleteButton")
                }
            } else {
                Button("Review effects") { model.makePreview() }.accessibilityIdentifier("completionPreviewButton")
            }
            if let completed = model.completed {
                Section("Completed") {
                    Text("Completion persisted").accessibilityIdentifier("persistentCompletionSuccess")
                    Text("Revision \(completed.revision): \(completed.resultCount) results, \(completed.reportCount) reports")
                        .accessibilityIdentifier("completionRevision-\(completed.revision)")
                    Button("Correct completion") { showsCorrection = true }.accessibilityIdentifier("correctionButton")
                }
            }
        }
        .navigationTitle("Session review")
        .sheet(isPresented: $showsCorrection) {
            NavigationStack {
                Form { TextField("Required reason", text: $correctionReason, axis: .vertical).accessibilityIdentifier("correctionReasonField") }
                    .navigationTitle("Correction")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showsCorrection = false } }
                        ToolbarItem(placement: .confirmationAction) { Button("Create revision") { if model.correct(reason: correctionReason) { showsCorrection = false } }.disabled(correctionReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("correctionSaveButton") }
                    }
            }
        }
        .accessibilityIdentifier("sessionCompletionReview")
    }
}
