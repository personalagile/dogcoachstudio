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
    func updateExercise(_ item: ExerciseSummary, title: String, goal: String, duration: Int, equipment: String) -> Bool {
        do {
            let (versionID, existing) = try exercises.editableDraft(exerciseID: item.id)
            var localization = existing.localizations.first(where: { $0.localeIdentifier == localeIdentifier }) ?? existing.localizations.first ?? ExerciseLocalizationDraft(localeIdentifier: localeIdentifier)
            localization.title = title; localization.goal = goal
            var draft = existing; draft.durationMinutes = duration; draft.equipment = equipment.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            draft.localizations = [localization]
            try exercises.updateDraft(versionID: versionID, draft: draft); reload(); return true
        } catch { self.error = AppErrorMapper.map(error, operation: "exercise.update"); return false }
    }
    func archiveExercise(_ item: ExerciseSummary) { do { try exercises.setArchived(exerciseID: item.id, archived: true); reload() } catch { self.error = AppErrorMapper.map(error, operation: "exercise.archive") } }
    func createTemplate(title: String, targetDuration: Int, exerciseIDs: [UUID]) -> Bool {
        let selected = exerciseItems.filter { exerciseIDs.contains($0.id) }
        let items = selected.map { TemplateExerciseDraft(id: uuid.makeUUID(), exerciseVersionID: $0.versionID, plannedDurationMinutes: $0.durationMinutes, trainerInstruction: nil) }
        do { _ = try templates.create(TrainingTemplateDraft(title: title, targetDurationMinutes: targetDuration, audience: "", trainerNotes: nil, exercises: items)); reload(); return true }
        catch { self.error = AppErrorMapper.map(error, operation: "template.create"); return false }
    }
    func publishTemplate(_ item: TrainingTemplateSummary) { do { try templates.publish(versionID: item.versionID, at: clock.now()); reload() } catch { self.error = AppErrorMapper.map(error, operation: "template.publish") } }
    func templateDraft(_ item: TrainingTemplateSummary) -> TrainingTemplateDraft? { try? templates.editableDraft(templateID: item.id).1 }
    func updateTemplate(_ item: TrainingTemplateSummary, title: String, targetDuration: Int, exerciseIDs: [UUID]) -> Bool {
        do {
            let (versionID, existing) = try templates.editableDraft(templateID: item.id)
            let selected = exerciseItems.filter { exerciseIDs.contains($0.id) }
            let rows = selected.map { exercise in TemplateExerciseDraft(id: uuid.makeUUID(), exerciseVersionID: exercise.versionID, plannedDurationMinutes: exercise.durationMinutes, trainerInstruction: nil) }
            try templates.updateDraft(versionID: versionID, draft: TrainingTemplateDraft(title: title, targetDurationMinutes: targetDuration, audience: existing.audience, trainerNotes: existing.trainerNotes, exercises: rows))
            reload(); return true
        } catch { self.error = AppErrorMapper.map(error, operation: "template.update"); return false }
    }
    func archiveTemplate(_ item: TrainingTemplateSummary) { do { try templates.setArchived(templateID: item.id, archived: true); reload() } catch { self.error = AppErrorMapper.map(error, operation: "template.archive") } }
}

struct CatalogRootView: View {
    @State private var model: CatalogFeatureModel
    @State private var sheet: Sheet?
    enum Sheet: Identifiable { case exercise(ExerciseSummary?), template(TrainingTemplateSummary?); var id: String { switch self { case .exercise(let item): "exercise-\(item?.id.uuidString ?? "new")"; case .template(let item): "template-\(item?.id.uuidString ?? "new")" } } }
    init(environment: AppEnvironment) { _model = State(initialValue: CatalogFeatureModel(environment: environment)) }

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            List {
                Section("Exercises") {
                    ForEach(model.exerciseItems) { item in
                        Button { sheet = .exercise(item) } label: { VStack(alignment: .leading, spacing: 4) {
                            HStack { Text(item.title).font(.headline); Spacer(); Text("v\(item.versionNumber)").font(.caption) }
                            Text(item.goal).font(.subheadline).foregroundStyle(.secondary)
                            if item.localeResolution.isFallback { Label("Translation missing – showing \(item.localeResolution.resolvedLocale)", systemImage: "globe.badge.chevron.backward").font(.caption).foregroundStyle(.orange) }
                            HStack { if let duration = item.durationMinutes { Text("\(duration) min") }; Text(item.isPublished ? "Published" : "Draft") }.font(.caption)
                        } }.buttonStyle(.plain)
                        .accessibilityIdentifier(item.isPublished ? "catalogPublishedExerciseRow" : "catalogDraftExerciseRow")
                        .swipeActions { Button("Archive", role: .destructive) { model.archiveExercise(item) }; if !item.isPublished { Button("Publish") { model.publishExercise(item) }.tint(.green) } }
                    }
                }
                Section("Templates") {
                    ForEach(model.templateItems) { item in
                        Button { sheet = .template(item) } label: { VStack(alignment: .leading) {
                            Text(item.title).font(.headline)
                            TemplateDurationLabel(item: item)
                        } }.buttonStyle(.plain)
                        .swipeActions { Button("Archive", role: .destructive) { model.archiveTemplate(item) }; if !item.isPublished { Button("Publish") { model.publishTemplate(item) }.tint(.green) } }
                    }
                }
            }
            .searchable(text: $model.query, prompt: "Search title, goal, or equipment").onChange(of: model.query) { model.reload() }
            .navigationTitle("Catalog")
            .toolbar { Menu("Add", systemImage: "plus") { Button("Exercise") { sheet = .exercise(nil) }; Button("Template") { sheet = .template(nil) } }.accessibilityIdentifier("catalogAddMenu") }
            .sheet(item: $sheet) { value in switch value { case .exercise(let item): ExerciseEditorView(model: model, item: item); case .template(let item): TemplateEditorView(model: model, item: item) } }
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
    let item: ExerciseSummary?
    @State private var title: String; @State private var goal: String; @State private var duration: Int; @State private var equipment: String
    init(model: CatalogFeatureModel, item: ExerciseSummary?) { self.model = model; self.item = item; _title = State(initialValue: item?.title ?? ""); _goal = State(initialValue: item?.goal ?? ""); _duration = State(initialValue: item?.durationMinutes ?? 5); _equipment = State(initialValue: item?.equipment.joined(separator: ", ") ?? "") }
    var body: some View { NavigationStack { Form { TextField("Title", text: $title).accessibilityIdentifier("exerciseTitleField"); TextField("Goal", text: $goal, axis: .vertical); Stepper("Duration: \(duration) min", value: $duration, in: 1...120); TextField("Equipment, comma separated", text: $equipment) }.navigationTitle(item == nil ? "New exercise" : "Edit exercise").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { let saved = item.map { model.updateExercise($0, title: title, goal: goal, duration: duration, equipment: equipment) } ?? model.createExercise(title: title, goal: goal, duration: duration, equipment: equipment); if saved { dismiss() } }.disabled(title.isEmpty).accessibilityIdentifier("exerciseSaveButton") } } } }
}

private struct TemplateEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let model: CatalogFeatureModel
    let item: TrainingTemplateSummary?
    @State private var title: String; @State private var duration: Int; @State private var selected: [UUID]
    init(model: CatalogFeatureModel, item: TrainingTemplateSummary?) { self.model = model; self.item = item; let draft = item.flatMap(model.templateDraft); _title = State(initialValue: draft?.title ?? ""); _duration = State(initialValue: draft?.targetDurationMinutes ?? 30); let versionIDs = Set(draft?.exercises.map(\.exerciseVersionID) ?? []); _selected = State(initialValue: model.exerciseItems.filter { versionIDs.contains($0.versionID) }.map(\.id)) }
    var body: some View { NavigationStack { Form { TextField("Title", text: $title).accessibilityIdentifier("templateTitleField"); Stepper("Target: \(duration) min", value: $duration, in: 5...240, step: 5); if !selected.isEmpty { Section("Selected order") { ForEach(selected, id: \.self) { id in Text(model.exerciseItems.first(where: { $0.id == id })?.title ?? "Exercise") }.onMove { selected.move(fromOffsets: $0, toOffset: $1) } }.environment(\.editMode, .constant(.active)) }; Section("Exercises") { ForEach(model.exerciseItems.filter { $0.isPublished }) { exercise in Button { if let index = selected.firstIndex(of: exercise.id) { selected.remove(at: index) } else { selected.append(exercise.id) } } label: { Label(exercise.title, systemImage: selected.contains(exercise.id) ? "checkmark.circle.fill" : "circle") }.buttonStyle(.plain) } } }.navigationTitle(item == nil ? "New template" : "Edit template").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { let saved = item.map { model.updateTemplate($0, title: title, targetDuration: duration, exerciseIDs: selected) } ?? model.createTemplate(title: title, targetDuration: duration, exerciseIDs: selected); if saved { dismiss() } }.disabled(title.isEmpty || selected.isEmpty).accessibilityIdentifier("templateSaveButton") } } } }
}
