import Foundation
import Observation

@MainActor
@Observable
final class SessionCompletionModel {
    enum Step: Int, CaseIterable {
        case attendance
        case outcome
        case exceptions
        case review
        case completed
    }

    private let service: PoCCompletionService
    private(set) var step: Step = .attendance
    private(set) var result: SessionCompletionResult?
    private(set) var errorMessage: String?
    private(set) var startedAt = ContinuousClock.now
    private(set) var completionDuration: Duration?
    private(set) var isCompleting = false

    var attendanceByBookingID: [Booking.ID: AttendanceStatus]
    var defaultOutcome: ExerciseOutcome
    var overrides: [ExerciseOverride]

    let dogs = DemoScenario.dogs
    let exercises = DemoScenario.exercises
    let bookings = DemoScenario.bookings

    private var completionToken = UUID()

    init(service: PoCCompletionService = PoCCompletionService()) {
        self.service = service
        attendanceByBookingID = DemoScenario.request.attendanceByBookingID
        defaultOutcome = DemoScenario.request.defaultOutcome
        overrides = DemoScenario.request.overrides
    }

    var attendedCount: Int {
        attendanceByBookingID.values.count(where: { $0 == .attended })
    }

    var expectedResultCount: Int { attendedCount * exercises.count }

    func dog(for booking: Booking) -> Dog? {
        dogs.first(where: { $0.id == booking.dogID })
    }

    func attendance(for booking: Booking) -> AttendanceStatus {
        attendanceByBookingID[booking.id] ?? .pending
    }

    func setAttendance(_ status: AttendanceStatus, for booking: Booking) {
        attendanceByBookingID[booking.id] = status
    }

    func outcome(for dog: Dog, exercise: Exercise) -> ExerciseOutcome {
        overrides.first(where: { $0.dogID == dog.id && $0.exerciseID == exercise.id })?.outcome
            ?? defaultOutcome
    }

    func setOutcome(_ outcome: ExerciseOutcome, for dog: Dog, exercise: Exercise) {
        overrides.removeAll(where: { $0.dogID == dog.id && $0.exerciseID == exercise.id })
        if outcome != defaultOutcome {
            overrides.append(ExerciseOverride(dogID: dog.id, exerciseID: exercise.id, outcome: outcome))
        }
    }

    func goBack() {
        guard let previous = Step(rawValue: step.rawValue - 1) else { return }
        step = previous
    }

    func advance() {
        errorMessage = nil
        guard attendanceByBookingID.values.allSatisfy({ $0 != .pending }) else {
            errorMessage = String(localized: "Resolve attendance for every booking.", comment: "Validation shown when attendance is missing")
            return
        }
        guard let next = Step(rawValue: step.rawValue + 1), next != .completed else { return }
        step = next
    }

    func complete() async {
        guard !isCompleting else { return }
        isCompleting = true
        errorMessage = nil
        defer { isCompleting = false }

        do {
            let completed = try await service.complete(token: completionToken, request: makeRequest())
            result = completed
            completionDuration = startedAt.duration(to: .now)
            step = .completed
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func makeRequest() -> SessionCompletionRequest {
        SessionCompletionRequest(
            sessionID: DemoScenario.request.sessionID,
            dogs: dogs,
            exercises: exercises,
            template: DemoScenario.template,
            packages: DemoScenario.packages,
            bookings: bookings,
            attendanceByBookingID: attendanceByBookingID,
            defaultOutcome: defaultOutcome,
            overrides: overrides
        )
    }
}

extension AttendanceStatus {
    var label: String {
        switch self {
        case .pending: String(localized: "Pending", comment: "Unresolved attendance status")
        case .attended: String(localized: "Attended", comment: "Dog attended a session")
        case .absent: String(localized: "Absent", comment: "Dog did not attend a session")
        }
    }
}

extension ExerciseOutcome {
    var label: String {
        switch self {
        case .notStarted: String(localized: "Not started", comment: "Exercise outcome")
        case .strongSupport: String(localized: "Strong support", comment: "Exercise outcome")
        case .lightSupport: String(localized: "Light support", comment: "Exercise outcome")
        case .independent: String(localized: "Independent", comment: "Exercise outcome")
        case .stableWithDistraction: String(localized: "Stable with distraction", comment: "Exercise outcome")
        }
    }
}
