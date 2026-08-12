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
    var scope: SessionCalendarScope = .day
    var focusedDate: Date
    var searchText = ""
    var selectedMonthDay: Date?

    init(environment: AppEnvironment, seedDemo: Bool = false) {
        context = environment.persistence.mainContext
        repository = .init(context: context, uuid: environment.uuidGenerator)
        completion = .init(context: context, clock: environment.clock, uuid: environment.uuidGenerator)
        clock = environment.clock
        uuid = environment.uuidGenerator
        focusedDate = environment.clock.now()
        if seedDemo { try? seedUITestDemo() }
        reload()
    }

    var visibleSessions: [ScheduledSessionSummary] {
        let calendar = Calendar.autoupdatingCurrent
        let interval: DateInterval? = switch scope {
        case .day: calendar.dateInterval(of: .day, for: focusedDate)
        case .week: calendar.dateInterval(of: .weekOfYear, for: focusedDate)
        case .month: calendar.dateInterval(of: .month, for: focusedDate)
        }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return sessions.filter { session in
            let isInPeriod = interval?.contains(session.startAt) ?? true
            let matches = query.isEmpty || session.title.localizedStandardContains(query)
                || session.participantNames.contains { $0.localizedStandardContains(query) }
                || session.labels.contains { $0.localizedStandardContains(query) }
            return isInPeriod && matches
        }
    }

    var periodTitle: String {
        switch scope {
        case .day: return focusedDate.formatted(date: .complete, time: .omitted)
        case .week:
            guard let interval = Calendar.autoupdatingCurrent.dateInterval(of: .weekOfYear, for: focusedDate) else { return "" }
            let end = interval.end.addingTimeInterval(-1)
            return "\(interval.start.formatted(.dateTime.day().month(.abbreviated))) – \(end.formatted(.dateTime.day().month(.abbreviated).year()))"
        case .month: return focusedDate.formatted(.dateTime.month(.wide).year())
        }
    }

    var monthDays: [Date?] {
        let calendar = Calendar.autoupdatingCurrent
        guard let interval = calendar.dateInterval(of: .month, for: focusedDate),
              let dayRange = calendar.range(of: .day, in: .month, for: focusedDate) else { return [] }
        let weekday = calendar.component(.weekday, from: interval.start)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        return Array(repeating: nil, count: leading) + dayRange.compactMap {
            calendar.date(byAdding: .day, value: $0 - 1, to: interval.start)
        }
    }

    func sessions(on day: Date) -> [ScheduledSessionSummary] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return sessions.filter { session in
            let matches = query.isEmpty || session.title.localizedStandardContains(query)
                || session.participantNames.contains { $0.localizedStandardContains(query) }
                || session.labels.contains { $0.localizedStandardContains(query) }
            return Calendar.autoupdatingCurrent.isDate(session.startAt, inSameDayAs: day) && matches
        }
    }

    var displayedSessions: [ScheduledSessionSummary] {
        guard scope == .month, let selectedMonthDay else { return visibleSessions }
        return sessions(on: selectedMonthDay)
    }

    func movePeriod(_ value: Int) {
        let component: Calendar.Component = switch scope { case .day: .day; case .week: .weekOfYear; case .month: .month }
        focusedDate = Calendar.autoupdatingCurrent.date(byAdding: component, value: value, to: focusedDate) ?? focusedDate
        if scope == .month { selectedMonthDay = nil }
    }

    func reload() {
        do {
            sessions = try repository.list()
            dogs = try context.fetch(FetchDescriptor<DogRecord>()).filter { !$0.isArchived }.map { ($0.id, $0.name) }
            templates = try SwiftDataTrainingTemplateRepository(context: context, uuid: uuid).summaries().filter(\.isPublished)
        } catch { self.error = AppErrorMapper.map(error, operation: "sessions.reload") }
    }

    func create(title: String, startAt: Date, duration: Int, kind: ScheduledSessionKind, templateVersionID: UUID?, dogIDs: [UUID], labels: [String] = [], packageUnits: Decimal = 1) -> Bool {
        do {
            _ = try repository.create(.init(title: title, startAt: startAt, durationMinutes: duration, locationText: nil, kind: kind, templateVersionID: templateVersionID, dogIDs: dogIDs, labels: labels, packageUnitsPerAttendee: packageUnits))
            reload(); return true
        } catch { self.error = AppErrorMapper.map(error, operation: "session.create"); return false }
    }

    func delete(_ session: ScheduledSessionSummary) {
        do { try repository.delete(sessionID: session.id); reload() }
        catch { self.error = AppErrorMapper.map(error, operation: "session.delete") }
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
        @Bindable var model = model
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Calendar view", selection: $model.scope) {
                    Text("Today").tag(SessionCalendarScope.day)
                    Text("Week").tag(SessionCalendarScope.week)
                    Text("Month").tag(SessionCalendarScope.month)
                }
                .pickerStyle(.segmented)
                .padding()
                .accessibilityIdentifier("sessionCalendarScope")
                HStack {
                    Button("Previous", systemImage: "chevron.left") { model.movePeriod(-1) }.labelStyle(.iconOnly)
                    Spacer()
                    Text(model.periodTitle).font(.headline).multilineTextAlignment(.center)
                    Spacer()
                    Button("Next", systemImage: "chevron.right") { model.movePeriod(1) }.labelStyle(.iconOnly)
                }
                .padding(.horizontal)
                if model.scope == .month {
                    MonthCalendarView(model: model)
                        .padding(.horizontal)
                        .padding(.top, 8)
                }
                List(model.displayedSessions) { session in
                    SessionOverviewRow(session: session) { model.select(session.id) }
                        .swipeActions { if !session.isEvaluated { Button("Delete", role: .destructive) { model.delete(session) } } }
                }
                .overlay {
                    if model.visibleSessions.isEmpty {
                        if model.searchText.isEmpty {
                            ContentUnavailableView("No sessions", systemImage: "calendar", description: Text("There are no sessions in this period."))
                        } else {
                            ContentUnavailableView.search(text: model.searchText)
                        }
                    }
                }
            }
            .navigationTitle("Sessions")
            .searchable(text: $model.searchText, prompt: "Search client or dog")
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
    @State private var startAt = Date.now
    @State private var duration = 45
    @State private var kind = ScheduledSessionKind.group
    @State private var templateVersionID: UUID?
    @State private var dogIDs: Set<UUID> = []
    @State private var labelsText = ""
    @State private var packageUnits: Decimal = 1

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title).accessibilityIdentifier("sessionTitleField")
                Section("Schedule") {
                    DatePicker("Date", selection: $startAt, displayedComponents: .date)
                        .accessibilityIdentifier("sessionDatePicker")
                    DatePicker("Time", selection: $startAt, displayedComponents: .hourAndMinute)
                        .accessibilityIdentifier("sessionTimePicker")
                }
                Stepper("Duration: \(duration) min", value: $duration, in: 5...240, step: 5)
                Picker("Kind", selection: $kind) { ForEach(ScheduledSessionKind.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) } }
                Picker("Template", selection: $templateVersionID) { Text("No template").tag(UUID?.none); ForEach(model.templates) { Text($0.title).tag(Optional($0.versionID)) } }
                TextField("Labels, comma separated", text: $labelsText).accessibilityIdentifier("sessionLabelsField")
                TextField("Package units per attendee", value: $packageUnits, format: .number).keyboardType(.decimalPad).accessibilityIdentifier("sessionPackageUnitsField")
                Section("Dogs") { ForEach(model.dogs, id: \.id) { dog in Toggle(dog.name, isOn: Binding(get: { dogIDs.contains(dog.id) }, set: { if $0 { dogIDs.insert(dog.id) } else { dogIDs.remove(dog.id) } })) } }
            }
            .navigationTitle("New session")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: dismiss) }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { if model.create(title: title, startAt: startAt, duration: duration, kind: kind, templateVersionID: templateVersionID, dogIDs: Array(dogIDs), labels: labelsText.split(separator: ",").map(String.init), packageUnits: packageUnits) { dismiss() } }.disabled(title.isEmpty || packageUnits < 0).accessibilityIdentifier("sessionSaveButton") }
            }
        }
    }
}

private struct SessionOverviewRow: View {
    let session: ScheduledSessionSummary
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(session.isEvaluated ? Color.green : Color.orange)
                    .frame(width: 6)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(session.startAt, format: .dateTime.weekday(.abbreviated).hour().minute()).font(.subheadline)
                        Spacer()
                        Label(session.isEvaluated ? "Evaluated" : "Evaluation pending", systemImage: session.isEvaluated ? "checkmark.circle.fill" : "clock.badge.exclamationmark")
                            .font(.caption)
                            .foregroundStyle(session.isEvaluated ? .green : .orange)
                    }
                    Text(session.title).font(.headline)
                    if !session.participantNames.isEmpty { Text(session.participantNames.joined(separator: ", ")).font(.subheadline).foregroundStyle(.secondary) }
                    Text("\(session.bookingCount) bookings · \(session.durationMinutes) min")
                    if !session.labels.isEmpty { Text(session.labels.map { "#\($0)" }.joined(separator: " ")).font(.caption).foregroundStyle(.secondary) }
                    if session.hasOverlap { Label("Overlaps another session", systemImage: "exclamationmark.triangle").foregroundStyle(.orange) }
                }
            }
        }
        .accessibilityIdentifier("scheduledSessionRow")
    }
}

private struct MonthCalendarView: View {
    let model: SessionsFeatureModel
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        VStack(spacing: 6) {
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(weekdaySymbols, id: \.self) { Text($0).font(.caption2).foregroundStyle(.secondary) }
                ForEach(monthSlots) { slot in
                    if let day = slot.day {
                        CalendarDayCell(
                            day: day,
                            sessions: model.sessions(on: day),
                            isSelected: model.selectedMonthDay.map { Calendar.autoupdatingCurrent.isDate($0, inSameDayAs: day) } ?? false
                        ) { model.selectedMonthDay = day }
                    }
                    else { Color.clear.frame(minHeight: 42) }
                }
            }
            HStack(spacing: 16) {
                Label("Evaluation pending", systemImage: "circle.fill").foregroundStyle(.orange)
                Label("Evaluated", systemImage: "circle.fill").foregroundStyle(.green)
            }
            .font(.caption)
            .accessibilityIdentifier("sessionEvaluationLegend")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("monthCalendar")
    }

    private var weekdaySymbols: [String] {
        let calendar = Calendar.autoupdatingCurrent
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let offset = calendar.firstWeekday - 1
        return Array(symbols[offset...] + symbols[..<offset])
    }

    private var monthSlots: [MonthDaySlot] {
        model.monthDays.enumerated().map { MonthDaySlot(position: $0.offset, day: $0.element) }
    }
}

private struct MonthDaySlot: Identifiable {
    let position: Int
    let day: Date?
    var id: Int { position }
}

private struct CalendarDayCell: View {
    let day: Date
    let sessions: [ScheduledSessionSummary]
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) { VStack(spacing: 3) {
            Text(day, format: .dateTime.day())
                .font(.callout)
            HStack(spacing: 2) {
                ForEach(Array(sessions.prefix(4).enumerated()), id: \.offset) { _, session in
                    Circle().fill(session.isEvaluated ? Color.green : Color.orange).frame(width: 6, height: 6)
                }
            }
        } }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, minHeight: 42)
        .background(isSelected ? Color.accentColor.opacity(0.28) : (Calendar.autoupdatingCurrent.isDateInToday(day) ? Color.accentColor.opacity(0.12) : Color.clear))
        .clipShape(.rect(cornerRadius: 8))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(day.formatted(date: .long, time: .omitted))
        .accessibilityValue("\(sessions.count) sessions, \(sessions.filter(\.isEvaluated).count) evaluated")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
