import AVKit
import CoreTransferable
import Observation
import PhotosUI
import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers

@MainActor @Observable
final class CatalogFeatureModel {
    private let exercises: SwiftDataExerciseRepository
    private let templates: SwiftDataTrainingTemplateRepository
    private let clock: any AppClock
    private let uuid: any UUIDGenerating
    private let mediaLibrary: ExerciseMediaLibrary?
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
        mediaLibrary = try? ExerciseMediaLibrary(uuid: environment.uuidGenerator)
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
    func createExercise(_ draft: ExerciseDraft) -> Bool {
        do { _ = try exercises.create(draft); reload(); return true }
        catch { self.error = AppErrorMapper.map(error, operation: "exercise.create"); return false }
    }
    func publishExercise(_ item: ExerciseSummary) { do { try exercises.publish(versionID: item.versionID, at: clock.now()); reload() } catch { self.error = AppErrorMapper.map(error, operation: "exercise.publish") } }
    func exerciseDraft(_ item: ExerciseSummary) -> ExerciseDraft? { try? exercises.editableDraft(exerciseID: item.id).1 }
    func updateExercise(_ item: ExerciseSummary, draft: ExerciseDraft) -> Bool {
        do {
            let (versionID, _) = try exercises.editableDraft(exerciseID: item.id)
            try exercises.updateDraft(versionID: versionID, draft: draft); reload(); return true
        } catch { self.error = AppErrorMapper.map(error, operation: "exercise.update"); return false }
    }
    func mediaAssets(exerciseID: UUID) async -> [ExerciseMediaAsset] {
        guard let mediaLibrary else { return [] }
        do { return try await mediaLibrary.assets(exerciseID: exerciseID) }
        catch { self.error = AppErrorMapper.map(error, operation: "exercise.media.load"); return [] }
    }
    func addPhoto(_ data: Data, exerciseID: UUID) async -> Bool {
        guard let mediaLibrary else { return false }
        do { _ = try await mediaLibrary.addPhoto(data: data, exerciseID: exerciseID, at: clock.now()); return true }
        catch { self.error = AppErrorMapper.map(error, operation: "exercise.media.photo"); return false }
    }
    func addVideo(_ url: URL, exerciseID: UUID) async -> Bool {
        guard let mediaLibrary else { return false }
        do { _ = try await mediaLibrary.addVideo(from: url, exerciseID: exerciseID, at: clock.now()); return true }
        catch { self.error = AppErrorMapper.map(error, operation: "exercise.media.video"); return false }
    }
    func removeMedia(_ asset: ExerciseMediaAsset) async -> Bool {
        guard let mediaLibrary else { return false }
        do { try await mediaLibrary.remove(asset); return true }
        catch { self.error = AppErrorMapper.map(error, operation: "exercise.media.delete"); return false }
    }
    func mediaURL(_ asset: ExerciseMediaAsset) -> URL? { mediaLibrary?.fileURL(for: asset) }
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
    @State private var title: String
    @State private var goal: String
    @State private var setup: String
    @State private var duration: Int
    @State private var equipment: String
    @State private var steps: [ExerciseTextEntry]
    @State private var successCriteria: [ExerciseTextEntry]
    @State private var problems: [ExerciseProblemMeasure]
    @State private var regression: String
    @State private var progression: String
    @State private var homework: String
    @State private var safetyNotes: String
    @State private var media: [ExerciseMediaAsset] = []
    @State private var photoSelection: PhotosPickerItem?
    @State private var videoSelection: PhotosPickerItem?
    @State private var selectedVideo: ExerciseMediaAsset?

    init(model: CatalogFeatureModel, item: ExerciseSummary?) {
        self.model = model
        self.item = item
        let draft = item.flatMap(model.exerciseDraft)
        let localization = draft?.localizations.first(where: {
            Locale(identifier: $0.localeIdentifier).language.languageCode == Locale.current.language.languageCode
        }) ?? draft?.localizations.first
        _title = State(initialValue: localization?.title ?? "")
        _goal = State(initialValue: localization?.goal ?? "")
        _setup = State(initialValue: localization?.setup ?? "")
        _duration = State(initialValue: draft?.durationMinutes ?? item?.durationMinutes ?? 5)
        _equipment = State(initialValue: (draft?.equipment ?? item?.equipment ?? []).joined(separator: ", "))
        _steps = State(initialValue: (localization?.steps ?? [""]).map { ExerciseTextEntry(value: $0) })
        _successCriteria = State(initialValue: (localization?.successCriteria ?? [""]).map { ExerciseTextEntry(value: $0) })
        let errors = localization?.commonErrors ?? []
        let measures = localization?.correctiveMeasures ?? []
        _problems = State(initialValue: errors.enumerated().map { index, problem in
            ExerciseProblemMeasure(problem: problem, measure: measures.indices.contains(index) ? measures[index] : "")
        })
        _regression = State(initialValue: localization?.regression ?? "")
        _progression = State(initialValue: localization?.progression ?? "")
        _homework = State(initialValue: localization?.homework ?? "")
        _safetyNotes = State(initialValue: localization?.safetyNotes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Basics") {
                    TextField("Title", text: $title).accessibilityIdentifier("exerciseTitleField")
                    TextField("Goal", text: $goal, axis: .vertical)
                    TextField("Setup", text: $setup, axis: .vertical)
                    Stepper("Duration: \(duration) min", value: $duration, in: 1...120)
                    TextField("Equipment, comma separated", text: $equipment)
                }
                EditableStringListSection(title: "Training steps", values: $steps, newValueLabel: "Add step")
                EditableStringListSection(title: "Success criteria", values: $successCriteria, newValueLabel: "Add criterion")
                Section("Problems and measures") {
                    ForEach($problems) { $problem in
                        VStack(alignment: .leading) {
                            TextField("Problem", text: $problem.problem, axis: .vertical)
                            TextField("Corrective measure", text: $problem.measure, axis: .vertical)
                        }
                        .swipeActions { Button("Delete", role: .destructive) { problems.removeAll { $0.id == problem.id } } }
                    }
                    Button("Add problem", systemImage: "plus") { problems.append(ExerciseProblemMeasure()) }
                }
                Section("Adjustments") {
                    TextField("Make it easier", text: $regression, axis: .vertical)
                    TextField("Make it harder", text: $progression, axis: .vertical)
                    TextField("Homework", text: $homework, axis: .vertical)
                    TextField("Safety notes", text: $safetyNotes, axis: .vertical)
                }
                mediaSection
            }
            .navigationTitle(item == nil ? "New exercise" : "Edit exercise")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { if save() { dismiss() } }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("exerciseSaveButton")
                }
            }
            .task(id: item?.id) { await reloadMedia() }
            .onChange(of: photoSelection) { _, selection in
                guard let selection, let exerciseID = item?.id else { return }
                Task {
                    if let data = try? await selection.loadTransferable(type: Data.self), await model.addPhoto(data, exerciseID: exerciseID) { await reloadMedia() }
                    photoSelection = nil
                }
            }
            .onChange(of: videoSelection) { _, selection in
                guard let selection, let exerciseID = item?.id else { return }
                Task {
                    if let movie = try? await selection.loadTransferable(type: ImportedExerciseMovie.self) {
                        if await model.addVideo(movie.url, exerciseID: exerciseID) { await reloadMedia() }
                        try? FileManager.default.removeItem(at: movie.url)
                    }
                    videoSelection = nil
                }
            }
            .sheet(item: $selectedVideo) { asset in
                if let url = model.mediaURL(asset) { ExerciseVideoPlayer(url: url) }
            }
        }
    }

    @ViewBuilder private var mediaSection: some View {
        Section("Photos and videos") {
            if let item {
                ScrollView(.horizontal) {
                    HStack {
                        ForEach(media) { asset in
                            ExerciseMediaThumbnail(asset: asset, url: model.mediaURL(asset)) {
                                if asset.kind == .video { selectedVideo = asset }
                            } delete: {
                                Task { if await model.removeMedia(asset) { await reloadMedia() } }
                            }
                        }
                    }
                }
                .frame(minHeight: media.isEmpty ? 0 : 120)
                PhotosPicker(selection: $photoSelection, matching: .images) { Label("Add photo", systemImage: "photo.badge.plus") }
                    .accessibilityIdentifier("exerciseAddPhotoButton")
                PhotosPicker(selection: $videoSelection, matching: .videos) { Label("Add video", systemImage: "video.badge.plus") }
                    .accessibilityIdentifier("exerciseAddVideoButton")
                if media.isEmpty { Text("No media yet").foregroundStyle(.secondary) }
                Text(item.isPublished ? "Editing creates a new draft version; media remains linked to the exercise." : "Media is stored locally on this device.")
                    .font(.footnote).foregroundStyle(.secondary)
            } else {
                Text("Save the exercise once before adding media.").foregroundStyle(.secondary)
            }
        }
    }

    private func save() -> Bool {
        let locale = item.flatMap(model.exerciseDraft)?.localizations.first?.localeIdentifier ?? Locale.current.identifier
        let localization = ExerciseLocalizationDraft(
            localeIdentifier: locale,
            title: title,
            goal: goal,
            setup: setup,
            steps: steps.map(\.value).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty },
            successCriteria: successCriteria.map(\.value).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty },
            commonErrors: problems.map(\.problem).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty },
            correctiveMeasures: problems.filter { !$0.problem.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.map(\.measure),
            regression: regression,
            progression: progression,
            homework: homework,
            safetyNotes: safetyNotes
        )
        var localizations = item.flatMap(model.exerciseDraft)?.localizations ?? []
        if let index = localizations.firstIndex(where: { $0.localeIdentifier == locale }) { localizations[index] = localization } else { localizations.append(localization) }
        let draft = ExerciseDraft(
            durationMinutes: duration,
            equipment: equipment.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty },
            localizations: localizations
        )
        return item.map { model.updateExercise($0, draft: draft) } ?? model.createExercise(draft)
    }

    private func reloadMedia() async {
        guard let exerciseID = item?.id else { media = []; return }
        media = await model.mediaAssets(exerciseID: exerciseID)
    }
}

private struct EditableStringListSection: View {
    let title: LocalizedStringResource
    @Binding var values: [ExerciseTextEntry]
    let newValueLabel: LocalizedStringResource

    var body: some View {
        Section(title) {
            ForEach($values) { $entry in
                TextField(newValueLabel, text: $entry.value, axis: .vertical)
                    .swipeActions { Button("Delete", role: .destructive) { values.removeAll { $0.id == entry.id } } }
            }
            Button(newValueLabel, systemImage: "plus") { values.append(ExerciseTextEntry()) }
        }
    }
}

private struct ExerciseTextEntry: Identifiable, Equatable {
    let id: UUID
    var value: String
    init(id: UUID = UUID(), value: String = "") { self.id = id; self.value = value }
}

private struct ImportedExerciseMovie: Transferable, Sendable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            let destination = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString).appendingPathExtension(received.file.pathExtension)
            try FileManager.default.copyItem(at: received.file, to: destination)
            return ImportedExerciseMovie(url: destination)
        }
    }
}

private struct ExerciseMediaThumbnail: View {
    let asset: ExerciseMediaAsset
    let url: URL?
    let open: () -> Void
    let delete: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            Button(action: open) {
                Group {
                    if asset.kind == .photo, let url, let image = UIImage(contentsOfFile: url.path) {
                        Image(uiImage: image).resizable().scaledToFill()
                    } else {
                        Image(systemName: "play.rectangle.fill").font(.largeTitle).foregroundStyle(.secondary)
                    }
                }
                .frame(width: 112, height: 84)
                .background(.quaternary)
                .clipShape(.rect(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(asset.kind == .photo ? "Exercise photo" : "Play exercise video")
            Button("Delete", systemImage: "trash", role: .destructive, action: delete).labelStyle(.iconOnly)
        }
    }
}

private struct ExerciseVideoPlayer: View {
    @Environment(\.dismiss) private var dismiss
    let url: URL
    @State private var player = AVPlayer()

    var body: some View {
        NavigationStack {
            VideoPlayer(player: player)
                .onAppear { player.replaceCurrentItem(with: AVPlayerItem(url: url)); player.play() }
                .onDisappear { player.pause() }
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                .navigationTitle("Exercise video")
        }
    }
}

private struct TemplateEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let model: CatalogFeatureModel
    let item: TrainingTemplateSummary?
    @State private var title: String; @State private var duration: Int; @State private var selected: [UUID]
    init(model: CatalogFeatureModel, item: TrainingTemplateSummary?) { self.model = model; self.item = item; let draft = item.flatMap(model.templateDraft); _title = State(initialValue: draft?.title ?? ""); _duration = State(initialValue: draft?.targetDurationMinutes ?? 30); let versionIDs = Set(draft?.exercises.map(\.exerciseVersionID) ?? []); _selected = State(initialValue: model.exerciseItems.filter { versionIDs.contains($0.versionID) }.map(\.id)) }
    var body: some View { NavigationStack { Form { TextField("Title", text: $title).accessibilityIdentifier("templateTitleField"); Stepper("Target: \(duration) min", value: $duration, in: 5...240, step: 5); if !selected.isEmpty { Section("Selected order") { ForEach(selected, id: \.self) { id in Text(model.exerciseItems.first(where: { $0.id == id })?.title ?? "Exercise") }.onMove { selected.move(fromOffsets: $0, toOffset: $1) } }.environment(\.editMode, .constant(.active)) }; Section("Exercises") { ForEach(model.exerciseItems.filter { $0.isPublished }) { exercise in Button { if let index = selected.firstIndex(of: exercise.id) { selected.remove(at: index) } else { selected.append(exercise.id) } } label: { Label(exercise.title, systemImage: selected.contains(exercise.id) ? "checkmark.circle.fill" : "circle") }.buttonStyle(.plain) } } }.navigationTitle(item == nil ? "New template" : "Edit template").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { let saved = item.map { model.updateTemplate($0, title: title, targetDuration: duration, exerciseIDs: selected) } ?? model.createTemplate(title: title, targetDuration: duration, exerciseIDs: selected); if saved { dismiss() } }.disabled(title.isEmpty || selected.isEmpty).accessibilityIdentifier("templateSaveButton") } } } }
}
