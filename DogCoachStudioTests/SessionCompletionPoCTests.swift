import Foundation
import Testing
@testable import DogCoachStudio

@Suite("Phase 0 session completion")
struct SessionCompletionPoCTests {
    @Test("The demo materializes exactly the attended dogs and their exercises")
    func attendanceControlsAllDownstreamArtifacts() async throws {
        let result = try await PoCCompletionService().complete(
            token: UUID(),
            request: DemoScenario.request
        )

        let attendedBookings = DemoScenario.bookings.prefix(6)
        let attendedDogIDs = Set(attendedBookings.map(\.dogID))
        let absentDogIDs = Set(DemoScenario.bookings.suffix(2).map(\.dogID))

        #expect(result.exerciseResults.count == 30)
        #expect(result.packageRedemptions.count == 6)
        #expect(result.reportDrafts.count == 6)
        #expect(Set(result.exerciseResults.map(\.dogID)) == attendedDogIDs)
        #expect(Set(result.reportDrafts.map(\.dogID)) == attendedDogIDs)
        #expect(result.exerciseResults.allSatisfy { !absentDogIDs.contains($0.dogID) })
        #expect(result.packageRedemptions.allSatisfy { $0.unitDelta == -1 })
        #expect(Set(result.packageRedemptions.map(\.bookingID)) == Set(attendedBookings.map(\.id)))

        let deviations = result.exerciseResults.filter { $0.outcome != DemoScenario.request.defaultOutcome }
        #expect(deviations.count == 3)
    }

    @Test("Replaying the same token and payload returns the same completion")
    func completionIsIdempotent() async throws {
        let service = PoCCompletionService()
        let token = UUID()

        let first = try await service.complete(token: token, request: DemoScenario.request)
        let replay = try await service.complete(token: token, request: DemoScenario.request)

        #expect(replay == first)
        #expect(Set(replay.exerciseResults.map(\.id)).count == 30)
        #expect(Set(replay.packageRedemptions.map(\.id)).count == 6)
        #expect(Set(replay.reportDrafts.map(\.id)).count == 6)
    }

    @Test("Reusing a token for a different payload is rejected")
    func tokenPayloadConflictIsRejected() async throws {
        let service = PoCCompletionService()
        let token = UUID()
        _ = try await service.complete(token: token, request: DemoScenario.request)

        let conflictingRequest = request(defaultOutcome: .notStarted)

        await #expect(throws: SessionCompletionError.tokenPayloadConflict) {
            try await service.complete(token: token, request: conflictingRequest)
        }
    }

    @Test("Every booking requires a resolved attendance state")
    func unresolvedAttendanceIsRejectedWithoutMutation() async throws {
        let service = PoCCompletionService()
        let token = UUID()
        var attendance = DemoScenario.request.attendanceByBookingID
        attendance[DemoScenario.bookings[0].id] = .pending
        let invalidRequest = request(attendance: attendance)

        await #expect(throws: (any Error).self) {
            try await service.complete(token: token, request: invalidRequest)
        }

        // If validation had partially committed, this retry would fail as already completed.
        let validResult = try await service.complete(token: token, request: DemoScenario.request)
        #expect(validResult.exerciseResults.count == 30)
        #expect(validResult.packageRedemptions.count == 6)
        #expect(validResult.reportDrafts.count == 6)
    }

    @Test("An override for an absent dog is rejected without mutation")
    func invalidOverrideIsRejectedWithoutMutation() async throws {
        let service = PoCCompletionService()
        let token = UUID()
        let invalidOverride = ExerciseOverride(
            dogID: DemoScenario.dogs[7].id,
            exerciseID: DemoScenario.exercises[0].id,
            outcome: .lightSupport
        )
        let invalidRequest = request(overrides: DemoScenario.request.overrides + [invalidOverride])

        await #expect(throws: (any Error).self) {
            try await service.complete(token: token, request: invalidRequest)
        }

        let validResult = try await service.complete(token: token, request: DemoScenario.request)
        #expect(validResult.exerciseResults.count == 30)
    }

    @Test("Report drafts never contain trainer-private notes")
    func reportsExcludePrivateData() async throws {
        let privateCanary = try #require(DemoScenario.dogs[0].trainerPrivateNote)
        let result = try await PoCCompletionService().complete(
            token: UUID(),
            request: DemoScenario.request
        )

        let reportText = result.reportDrafts.flatMap { report in
            [report.dogName] + report.results.flatMap { [$0.exerciseTitle, $0.outcome.rawValue] }
        }.joined(separator: "\n")

        #expect(!reportText.contains(privateCanary))
    }

    @Test("Completed results retain exercise snapshots after a template edit")
    func templateChangesDoNotMutateCompletedSnapshots() async throws {
        let service = PoCCompletionService()
        let token = UUID()
        let completed = try await service.complete(token: token, request: DemoScenario.request)
        let snapshots = completed.exerciseResults.map(\.exercise)

        let editedExercises = DemoScenario.exercises.map {
            Exercise(id: $0.id, title: "Edited \($0.title)")
        }
        _ = request(
            exercises: editedExercises,
            template: TrainingTemplate(
                id: DemoScenario.template.id,
                title: "Edited template",
                exerciseIDs: editedExercises.map(\.id)
            )
        )

        let replay = try await service.complete(token: token, request: DemoScenario.request)
        #expect(replay.exerciseResults.map(\.exercise) == snapshots)
        #expect(replay.exerciseResults.allSatisfy { !$0.exercise.title.hasPrefix("Edited ") })
    }
}

private func request(
    sessionID: UUID = DemoScenario.request.sessionID,
    dogs: [Dog] = DemoScenario.request.dogs,
    exercises: [Exercise] = DemoScenario.request.exercises,
    template: TrainingTemplate = DemoScenario.request.template,
    packages: [DemoPackage] = DemoScenario.request.packages,
    bookings: [Booking] = DemoScenario.request.bookings,
    attendance: [Booking.ID: AttendanceStatus] = DemoScenario.request.attendanceByBookingID,
    defaultOutcome: ExerciseOutcome = DemoScenario.request.defaultOutcome,
    overrides: [ExerciseOverride] = DemoScenario.request.overrides
) -> SessionCompletionRequest {
    SessionCompletionRequest(
        sessionID: sessionID,
        dogs: dogs,
        exercises: exercises,
        template: template,
        packages: packages,
        bookings: bookings,
        attendanceByBookingID: attendance,
        defaultOutcome: defaultOutcome,
        overrides: overrides
    )
}
