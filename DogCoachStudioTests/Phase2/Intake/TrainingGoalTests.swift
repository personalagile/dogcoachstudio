import Foundation
import SwiftData
import Testing
@testable import DogCoachStudio

@Suite("Phase 2 training goals")
struct TrainingGoalTests {
    @Test("Terminal transitions set completion date and reopening clears it")
    func statusTransitions() {
        let date = Date(timeIntervalSince1970: 1_750_000_000)
        var goal = TrainingGoal(dogID: UUID(), title: "Calm greeting")

        goal.transition(to: .achieved, at: date)
        #expect(goal.status == .achieved)
        #expect(goal.completedAt == date)

        goal.transition(to: .active, at: date.addingTimeInterval(60))
        #expect(goal.status == .active)
        #expect(goal.completedAt == nil)
    }

    @Test("Goals can be created, updated, listed per dog, and deleted")
    @MainActor
    func repositoryLifecycle() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let dog = DogRecord(name: "Goal Dog")
        let otherDog = DogRecord(name: "Other Dog")
        container.mainContext.insert(dog)
        container.mainContext.insert(otherDog)
        try container.mainContext.save()
        let repository = SwiftDataTrainingGoalRepository(context: container.mainContext)
        var goal = TrainingGoal(dogID: dog.id, title: "Loose lead", targetDescription: "Ten steps")
        let unrelated = TrainingGoal(dogID: otherDog.id, title: "Settle")

        try repository.save(goal)
        try repository.save(unrelated)
        #expect(try repository.goals(for: dog.id) == [goal])

        goal.transition(to: .achieved, at: Date(timeIntervalSince1970: 1_750_000_000))
        goal.targetDescription = "Twenty steps"
        try repository.save(goal)
        #expect(try repository.goals(for: dog.id) == [goal])

        try repository.delete(id: goal.id)
        #expect(try repository.goals(for: dog.id).isEmpty)
        #expect(try repository.goals(for: otherDog.id) == [unrelated])
    }

    @Test("Blank goal titles are rejected without persistence")
    @MainActor
    func blankTitleRejected() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let dog = DogRecord(name: "Goal Dog")
        container.mainContext.insert(dog)
        try container.mainContext.save()
        let repository = SwiftDataTrainingGoalRepository(context: container.mainContext)
        let invalid = TrainingGoal(dogID: dog.id, title: "   ")

        #expect(throws: AppError.validation(code: "training-goal.title-required")) {
            try repository.save(invalid)
        }
        #expect(try repository.goals(for: dog.id).isEmpty)
    }
}
