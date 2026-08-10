import Foundation
import SwiftData
import Testing
@testable import DogCoachStudio

@Suite("Phase 2 intake drafts")
struct IntakeDraftTests {
    @Test("Flushed drafts recover all client-facing and private fields")
    @MainActor
    func autosaveFlushAndRecovery() throws {
        let fixture = try IntakeFixture()
        let draft = fixture.makeDraft()
        let autosave = IntakeDraftAutosave(repository: fixture.repository, delay: .seconds(30))

        autosave.schedule(draft)
        try autosave.flush()

        #expect(try fixture.repository.draft(id: draft.id) == draft)
        #expect(try fixture.repository.drafts(for: fixture.dog.id) == [draft])
    }

    @Test("Scheduling a newer draft replaces the pending value")
    @MainActor
    func latestDraftWins() throws {
        let fixture = try IntakeFixture()
        var draft = fixture.makeDraft()
        let autosave = IntakeDraftAutosave(repository: fixture.repository, delay: .seconds(30))
        autosave.schedule(draft)
        draft.clientFacing.reason = "Latest reason"
        draft.privateFields.trainerNotes = "Latest private note"
        autosave.schedule(draft)
        try autosave.flush()

        let recovered = try #require(try fixture.repository.draft(id: draft.id))
        #expect(recovered.clientFacing.reason == "Latest reason")
        #expect(recovered.privateFields.trainerNotes == "Latest private note")
    }

    @Test("Private notes remain structurally separate from client-facing fields")
    @MainActor
    func privateFieldsDoNotLeak() throws {
        let fixture = try IntakeFixture()
        let canary = "PRIVATE-CANARY-person@example.test"
        var draft = fixture.makeDraft()
        draft.privateFields.trainerNotes = canary
        try fixture.repository.save(draft)
        let recovered = try #require(try fixture.repository.draft(id: draft.id))

        let clientFacingText = [
            recovered.clientFacing.reason,
            recovered.clientFacing.environment,
            recovered.clientFacing.history,
            recovered.clientFacing.knownTriggers,
            recovered.clientFacing.previousTraining,
            recovered.clientFacing.healthNotes,
            recovered.clientFacing.desiredOutcome
        ].joined(separator: "\n")
        #expect(!clientFacingText.contains(canary))
        #expect(recovered.privateFields.trainerNotes == canary)
    }
}

@MainActor
private struct IntakeFixture {
    let container: ModelContainer
    let dog: DogRecord
    let repository: SwiftDataIntakeRepository

    init() throws {
        container = try ModelContainerFactory.makeInMemory()
        dog = DogRecord(name: "Intake Dog")
        container.mainContext.insert(dog)
        try container.mainContext.save()
        repository = SwiftDataIntakeRepository(context: container.mainContext)
    }

    func makeDraft() -> IntakeDraft {
        IntakeDraft(
            dogID: dog.id,
            occurredAt: Date(timeIntervalSince1970: 1_750_000_000),
            clientFacing: IntakeClientFacingFields(
                reason: "Reason", environment: "Home", history: "History",
                knownTriggers: "Trigger", previousTraining: "Previous",
                healthNotes: "Health", desiredOutcome: "Outcome"
            ),
            privateFields: IntakePrivateFields(trainerNotes: "Trainer only")
        )
    }
}
