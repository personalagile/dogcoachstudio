import SwiftUI

struct SessionCompletionView: View {
    @State private var model = SessionCompletionModel()

    var body: some View {
        NavigationStack {
            Group {
                switch model.step {
                case .attendance: attendanceStep
                case .outcome: outcomeStep
                case .exceptions: exceptionsStep
                case .review: reviewStep
                case .completed: completedStep
                }
            }
            .navigationTitle("Demo session")
            .safeAreaInset(edge: .bottom) { actionBar }
        }
        .accessibilityIdentifier("sessionCompletionFlow")
    }

    private var attendanceStep: some View {
        List(model.bookings) { booking in
            if let dog = model.dog(for: booking) {
                HStack {
                    Text(dog.name)
                    Spacer()
                    Picker("Attendance for \(dog.name)", selection: attendanceBinding(for: booking)) {
                        Text("Attended").tag(AttendanceStatus.attended)
                        Text("Absent").tag(AttendanceStatus.absent)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 240)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .accessibilityIdentifier("attendanceList")
    }

    private var outcomeStep: some View {
        Form {
            Section("Default result") {
                Picker("Default result", selection: $model.defaultOutcome) {
                    ForEach(ExerciseOutcome.allCases, id: \.self) { outcome in
                        Text(outcome.label).tag(outcome)
                    }
                }
                .pickerStyle(.inline)
                .accessibilityIdentifier("defaultOutcomePicker")
            }
            Section {
                Text("This result is applied to all \(model.attendedCount) attending dogs. You only edit exceptions next.")
            }
        }
    }

    private var exceptionsStep: some View {
        List {
            ForEach(attendingDogs) { dog in
                Section(dog.name) {
                    ForEach(model.exercises) { exercise in
                        Picker(exercise.title, selection: outcomeBinding(for: dog, exercise: exercise)) {
                            ForEach(ExerciseOutcome.allCases, id: \.self) { outcome in
                                Text(outcome.label).tag(outcome)
                            }
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("exceptionsList")
    }

    private var reviewStep: some View {
        List {
            Section("Review") {
                summaryRow("Attending dogs", value: model.attendedCount)
                summaryRow("Exercise results", value: model.expectedResultCount)
                summaryRow("Package redemptions", value: model.attendedCount)
                summaryRow("Report drafts", value: model.attendedCount)
            }
            Section("Exceptions") {
                Text("\(model.overrides.count) results differ from the default.")
            }
            if let errorMessage = model.errorMessage {
                Section("Could not complete") { Text(errorMessage) }
            }
        }
        .accessibilityIdentifier("completionReview")
    }

    private var completedStep: some View {
        List {
            Section {
                Label("Session completed", systemImage: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
                    .accessibilityIdentifier("completionSuccess")
                if let duration = model.completionDuration {
                    Text("Elapsed: \(duration.formatted(.units(allowed: [.minutes, .seconds], width: .abbreviated)))")
                }
            }
            Section("Report drafts") {
                ForEach(model.result?.reportDrafts ?? []) { report in
                    DisclosureGroup(report.dogName) {
                        ForEach(report.results, id: \.exerciseTitle) { line in
                            LabeledContent(line.exerciseTitle, value: line.outcome.label)
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("completedReports")
    }

    @ViewBuilder
    private var actionBar: some View {
        if model.step != .completed {
            HStack {
                if model.step != .attendance {
                    Button("Back", systemImage: "chevron.left") { model.goBack() }
                }
                Spacer()
                if model.step == .review {
                    Button("Complete session", systemImage: "checkmark") {
                        Task { await model.complete() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.isCompleting)
                    .accessibilityIdentifier("completeSessionButton")
                } else {
                    Button("Continue", systemImage: "chevron.right") { model.advance() }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("continueButton")
                }
            }
            .padding()
            .background(.bar)
        }
    }

    private var attendingDogs: [Dog] {
        model.bookings.compactMap { booking in
            model.attendance(for: booking) == .attended ? model.dog(for: booking) : nil
        }
    }

    private func attendanceBinding(for booking: Booking) -> Binding<AttendanceStatus> {
        Binding(
            get: { model.attendance(for: booking) },
            set: { model.setAttendance($0, for: booking) }
        )
    }

    private func outcomeBinding(for dog: Dog, exercise: Exercise) -> Binding<ExerciseOutcome> {
        Binding(
            get: { model.outcome(for: dog, exercise: exercise) },
            set: { model.setOutcome($0, for: dog, exercise: exercise) }
        )
    }

    private func summaryRow(_ label: String, value: Int) -> some View {
        LabeledContent(label, value: value.formatted())
    }
}

#Preview {
    SessionCompletionView()
}
