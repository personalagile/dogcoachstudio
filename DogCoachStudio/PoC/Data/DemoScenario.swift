import Foundation

enum DemoScenario {
    private static func id(_ value: UInt8) -> UUID {
        UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, value))
    }

    static let sessionID = id(1)

    static let dogs: [Dog] = [
        Dog(id: id(11), name: "Luna", trainerPrivateNote: "Private demo note"),
        Dog(id: id(12), name: "Milo", trainerPrivateNote: nil),
        Dog(id: id(13), name: "Nala", trainerPrivateNote: nil),
        Dog(id: id(14), name: "Balu", trainerPrivateNote: nil),
        Dog(id: id(15), name: "Frieda", trainerPrivateNote: nil),
        Dog(id: id(16), name: "Bruno", trainerPrivateNote: nil),
        Dog(id: id(17), name: "Kira", trainerPrivateNote: nil),
        Dog(id: id(18), name: "Cooper", trainerPrivateNote: nil)
    ]

    static let exercises: [Exercise] = [
        Exercise(id: id(31), title: "Exercise 1"),
        Exercise(id: id(32), title: "Exercise 2"),
        Exercise(id: id(33), title: "Exercise 3"),
        Exercise(id: id(34), title: "Exercise 4"),
        Exercise(id: id(35), title: "Exercise 5")
    ]

    static let template = TrainingTemplate(
        id: id(40),
        title: "Phase 0 Demo Session",
        exerciseIDs: exercises.map(\.id)
    )

    static let packages: [DemoPackage] = dogs.enumerated().map { index, dog in
        DemoPackage(id: id(UInt8(51 + index)), dogID: dog.id, initialUnits: 10)
    }

    static let bookings: [Booking] = dogs.enumerated().map { index, dog in
        Booking(id: id(UInt8(71 + index)), dogID: dog.id, packageID: packages[index].id)
    }

    static let request = SessionCompletionRequest(
        sessionID: sessionID,
        dogs: dogs,
        exercises: exercises,
        template: template,
        packages: packages,
        bookings: bookings,
        attendanceByBookingID: Dictionary(
            uniqueKeysWithValues: bookings.enumerated().map { index, booking in
                (booking.id, index < 6 ? .attended : .absent)
            }
        ),
        defaultOutcome: .independent,
        overrides: [
            ExerciseOverride(dogID: dogs[0].id, exerciseID: exercises[0].id, outcome: .lightSupport),
            ExerciseOverride(dogID: dogs[2].id, exerciseID: exercises[2].id, outcome: .strongSupport),
            ExerciseOverride(dogID: dogs[5].id, exerciseID: exercises[4].id, outcome: .stableWithDistraction)
        ]
    )
}
