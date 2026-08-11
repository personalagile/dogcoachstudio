import Observation
import SwiftData
import SwiftUI

@MainActor @Observable
final class CatalogFeatureModel {
    private let exercises: SwiftDataExerciseRepository
    private let templates: SwiftDataTrainingTemplateRepository
    private let clock: any AppClock
    private let uuid: any UUIDGenerating
    var exerciseItems: [ExerciseSummary] = []
    var templateItems: [TrainingTemplateSummary] = []
    var query = ""
    var localeIdentifier = Locale.current.identifier
    var error: AppError?

    init(environment: AppEnvironment) {
        let context = environment.persistence.mainContext
        exercises = SwiftDataExerciseRepository(context: context, uuid: environment.uuidGenerator)
        templates = SwiftDataTrainingTemplateRepository(context: context, uuid: environment.uuidGenerator)
        clock = environment.clock; uuid = environment.uuidGenerator
        if let url = Bundle.main.url(forResource: "foundation-v1", withExtension: "json"), let data = try? Data(contentsOf: url) {
            do { _ = try ContentPackImporter(context: context, uuid: environment.uuidGenerator).importPack(data: data) }
            catch { self.error = AppErrorMapper.map(error, operation: "content-pack.bootstrap") }
        }
        reload()
    }

    func reload() {
        do { exerciseItems = try exercises.search(query, locale: localeIdentifier, includeArchived: false); templateItems = try templates.summaries(); if error == nil { error = nil } }
        catch { self.error = AppErrorMapper.map(error, operation: "catalog.reload") }
    }
    func createExercise(title: String, goal: String, duration: Int, equipment: String) -> Bool {
        let localization = ExerciseLocalizationDraft(localeIdentifier: localeIdentifier, title: title, goal: goal, steps: [String(localized: "Add training steps")], successCriteria: [String(localized: "Add success criteria")])
        do { _ = try exercises.create(ExerciseDraft(durationMinutes: duration, equipment: equipment.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }, localizations: [localization])); reload(); return true }
        catch { self.error = AppErrorMapper.map(error, operation: "exercise.create"); return false }
    }
    func publishExercise(_ item: ExerciseSummary) { do { try exercises.publish(versionID: item.versionID, at: clock.now()); reload() } catch { self.error = AppErrorMapper.map(error, operation: "exercise.publish") } }
    func createTemplate(title: String, targetDuration: Int, exerciseIDs: [UUID]) -> Bool {
        let selected = exerciseItems.filter { exerciseIDs.contains($0.id) }
        let items = selected.map { TemplateExerciseDraft(id: uuid.makeUUID(), exerciseVersionID: $0.versionID, plannedDurationMinutes: $0.durationMinutes, trainerInstruction: nil) }
        do { _ = try templates.create(TrainingTemplateDraft(title: title, targetDurationMinutes: targetDuration, audience: "", trainerNotes: nil, exercises: items)); reload(); return true }
        catch { self.error = AppErrorMapper.map(error, operation: "template.create"); return false }
    }
    func publishTemplate(_ item: TrainingTemplateSummary) { do { try templates.publish(versionID: item.versionID, at: clock.now()); reload() } catch { self.error = AppErrorMapper.map(error, operation: "template.publish") } }
}

struct CatalogRootView: View {
    @State private var model: CatalogFeatureModel
    @State private var sheet: Sheet?
    enum Sheet: String, Identifiable { case exercise, template; var id: String { rawValue } }
    init(environment: AppEnvironment) { _model = State(initialValue: CatalogFeatureModel(environment: environment)) }

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            List {
                Section("Exercises") {
                    ForEach(model.exerciseItems) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack { Text(item.title).font(.headline); Spacer(); Text("v\(item.versionNumber)").font(.caption) }
                            Text(item.goal).font(.subheadline).foregroundStyle(.secondary)
                            if item.localeResolution.isFallback { Label("Translation missing – showing \(item.localeResolution.resolvedLocale)", systemImage: "globe.badge.chevron.backward").font(.caption).foregroundStyle(.orange) }
                            HStack { if let duration = item.durationMinutes { Text("\(duration) min") }; Text(item.isPublished ? "Published" : "Draft") }.font(.caption)
                        }
                        .accessibilityIdentifier(item.isPublished ? "catalogPublishedExerciseRow" : "catalogDraftExerciseRow")
                        .swipeActions { if !item.isPublished { Button("Publish") { model.publishExercise(item) }.tint(.green) } }
                    }
                }
                Section("Templates") {
                    ForEach(model.templateItems) { item in
                        VStack(alignment: .leading) {
                            Text(item.title).font(.headline)
                            TemplateDurationLabel(item: item)
                        }
                        .swipeActions { if !item.isPublished { Button("Publish") { model.publishTemplate(item) }.tint(.green) } }
                    }
                }
            }
            .searchable(text: $model.query, prompt: "Search title, goal, or equipment").onChange(of: model.query) { model.reload() }
            .navigationTitle("Catalog")
            .toolbar { Menu("Add", systemImage: "plus") { Button("Exercise") { sheet = .exercise }; Button("Template") { sheet = .template } }.accessibilityIdentifier("catalogAddMenu") }
            .sheet(item: $sheet) { value in if value == .exercise { ExerciseEditorView(model: model) } else { TemplateEditorView(model: model) } }
            .accessibilityIdentifier("catalogRoot")
        }
    }
}

private struct TemplateDurationLabel: View {
    let item: TrainingTemplateSummary

    var body: some View {
        Text("\(item.exerciseCount) exercises · \(item.plannedDurationMinutes)/\(item.targetDurationMinutes) min")
            .font(.caption)
            .foregroundStyle(item.plannedDurationMinutes == item.targetDurationMinutes ? Color.secondary : Color.orange)
    }
}

private struct ExerciseEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let model: CatalogFeatureModel
    @State private var title = ""; @State private var goal = ""; @State private var duration = 5; @State private var equipment = ""
    var body: some View { NavigationStack { Form { TextField("Title", text: $title).accessibilityIdentifier("exerciseTitleField"); TextField("Goal", text: $goal, axis: .vertical); Stepper("Duration: \(duration) min", value: $duration, in: 1...120); TextField("Equipment, comma separated", text: $equipment) }.navigationTitle("New exercise").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { if model.createExercise(title: title, goal: goal, duration: duration, equipment: equipment) { dismiss() } }.disabled(title.isEmpty).accessibilityIdentifier("exerciseSaveButton") } } } }
}

private struct TemplateEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let model: CatalogFeatureModel
    @State private var title = ""; @State private var duration = 30; @State private var selected: [UUID] = []
    var body: some View { NavigationStack { Form { TextField("Title", text: $title).accessibilityIdentifier("templateTitleField"); Stepper("Target: \(duration) min", value: $duration, in: 5...240, step: 5); if !selected.isEmpty { Section("Selected order") { ForEach(selected, id: \.self) { id in Text(model.exerciseItems.first(where: { $0.id == id })?.title ?? "Exercise") }.onMove { selected.move(fromOffsets: $0, toOffset: $1) } }.environment(\.editMode, .constant(.active)) }; Section("Exercises") { ForEach(model.exerciseItems.filter { $0.isPublished }) { item in Button { if let index = selected.firstIndex(of: item.id) { selected.remove(at: index) } else { selected.append(item.id) } } label: { Label(item.title, systemImage: selected.contains(item.id) ? "checkmark.circle.fill" : "circle") }.buttonStyle(.plain) } } }.navigationTitle("New template").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { if model.createTemplate(title: title, targetDuration: duration, exerciseIDs: selected) { dismiss() } }.disabled(title.isEmpty || selected.isEmpty).accessibilityIdentifier("templateSaveButton") } } } }
}
