import Foundation

actor PoCCompletionService {
    private struct CompletedRequest: Sendable {
        let request: SessionCompletionRequest
        let result: SessionCompletionResult
    }

    private var completionsByToken: [UUID: CompletedRequest] = [:]
    private var tokenBySessionID: [UUID: UUID] = [:]

    func complete(
        token: UUID,
        request: SessionCompletionRequest
    ) throws -> SessionCompletionResult {
        if let completed = completionsByToken[token] {
            guard completed.request == request else {
                throw SessionCompletionError.tokenPayloadConflict
            }
            return completed.result
        }

        guard tokenBySessionID[request.sessionID] == nil else {
            throw SessionCompletionError.sessionAlreadyCompleted
        }

        try validate(request)
        let result = buildResult(token: token, request: request)

        completionsByToken[token] = CompletedRequest(request: request, result: result)
        tokenBySessionID[request.sessionID] = token
        return result
    }

    private func validate(_ request: SessionCompletionRequest) throws {
        guard !request.bookings.isEmpty else {
            throw SessionCompletionError.invalidRequest("At least one booking is required.")
        }

        guard Set(request.bookings.map(\.id)).count == request.bookings.count,
              Set(request.dogs.map(\.id)).count == request.dogs.count,
              Set(request.exercises.map(\.id)).count == request.exercises.count,
              Set(request.packages.map(\.id)).count == request.packages.count else {
            throw SessionCompletionError.invalidRequest("Entity identifiers must be unique.")
        }

        let dogsByID = Dictionary(uniqueKeysWithValues: request.dogs.map { ($0.id, $0) })
        let packagesByID = Dictionary(uniqueKeysWithValues: request.packages.map { ($0.id, $0) })
        let exercisesByID = Dictionary(uniqueKeysWithValues: request.exercises.map { ($0.id, $0) })
        let bookingsByID = Dictionary(uniqueKeysWithValues: request.bookings.map { ($0.id, $0) })

        guard request.attendanceByBookingID.keys.allSatisfy({ bookingsByID[$0] != nil }),
              request.bookings.allSatisfy({ request.attendanceByBookingID[$0.id] != nil }),
              !request.attendanceByBookingID.values.contains(.pending) else {
            throw SessionCompletionError.invalidRequest("Attendance must resolve every booking.")
        }

        guard request.template.exerciseIDs.count == Set(request.template.exerciseIDs).count,
              request.template.exerciseIDs.allSatisfy({ exercisesByID[$0] != nil }) else {
            throw SessionCompletionError.invalidRequest("The template must reference unique, known exercises.")
        }

        for booking in request.bookings {
            guard dogsByID[booking.dogID] != nil,
                  let package = packagesByID[booking.packageID],
                  package.dogID == booking.dogID,
                  package.initialUnits > 0 else {
                throw SessionCompletionError.invalidRequest("Every booking needs a valid dog package.")
            }
        }

        let attendedDogIDs = Set(request.bookings.compactMap { booking in
            request.attendanceByBookingID[booking.id] == .attended ? booking.dogID : nil
        })
        let overrideKeys = request.overrides.map { OverrideKey(dogID: $0.dogID, exerciseID: $0.exerciseID) }
        guard Set(overrideKeys).count == overrideKeys.count,
              request.overrides.allSatisfy({
                  attendedDogIDs.contains($0.dogID) && request.template.exerciseIDs.contains($0.exerciseID)
              }) else {
            throw SessionCompletionError.invalidRequest("Overrides must be unique and belong to attended dogs and template exercises.")
        }
    }

    private func buildResult(
        token: UUID,
        request: SessionCompletionRequest
    ) -> SessionCompletionResult {
        let dogsByID = Dictionary(uniqueKeysWithValues: request.dogs.map { ($0.id, $0) })
        let exercisesByID = Dictionary(uniqueKeysWithValues: request.exercises.map { ($0.id, $0) })
        let overridesByKey = Dictionary(uniqueKeysWithValues: request.overrides.map {
            (OverrideKey(dogID: $0.dogID, exerciseID: $0.exerciseID), $0.outcome)
        })
        let attendedBookings = request.bookings.filter {
            request.attendanceByBookingID[$0.id] == .attended
        }

        var results: [DogExerciseResult] = []
        var reports: [ReportDraft] = []

        for booking in attendedBookings {
            let dogResults = request.template.exerciseIDs.compactMap { exerciseID -> DogExerciseResult? in
                guard let exercise = exercisesByID[exerciseID] else { return nil }
                let outcome = overridesByKey[OverrideKey(dogID: booking.dogID, exerciseID: exerciseID)]
                    ?? request.defaultOutcome
                return DogExerciseResult(
                    id: UUID(),
                    dogID: booking.dogID,
                    exercise: ExerciseSnapshot(exerciseID: exercise.id, title: exercise.title),
                    outcome: outcome
                )
            }
            results.append(contentsOf: dogResults)

            if let dog = dogsByID[booking.dogID] {
                reports.append(ReportDraft(
                    id: UUID(),
                    dogID: dog.id,
                    dogName: dog.name,
                    results: dogResults.map {
                        ReportResultLine(exerciseTitle: $0.exercise.title, outcome: $0.outcome)
                    }
                ))
            }
        }

        let redemptions = attendedBookings.map {
            SimulatedPackageRedemption(
                id: UUID(),
                bookingID: $0.id,
                packageID: $0.packageID,
                unitDelta: -1
            )
        }

        return SessionCompletionResult(
            sessionID: request.sessionID,
            completionToken: token,
            exerciseResults: results,
            packageRedemptions: redemptions,
            reportDrafts: reports
        )
    }
}

private struct OverrideKey: Hashable, Sendable {
    let dogID: Dog.ID
    let exerciseID: Exercise.ID
}
