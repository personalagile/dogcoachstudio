import Foundation

@MainActor
final class IntakeDraftAutosave {
    private let repository: any IntakeRepository
    private let delay: Duration
    private var pendingTask: Task<Void, Never>?
    private var pendingDraft: IntakeDraft?

    private(set) var lastError: AppError?

    init(
        repository: any IntakeRepository,
        delay: Duration = .milliseconds(500)
    ) {
        self.repository = repository
        self.delay = delay
    }

    /// Replaces any pending save. Call `flush()` when leaving the editing flow.
    func schedule(_ draft: IntakeDraft) {
        pendingTask?.cancel()
        pendingDraft = draft
        lastError = nil

        pendingTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(for: delay)
                try Task.checkCancellation()
                try savePendingDraft()
            } catch is CancellationError {
                return
            } catch let error as AppError {
                lastError = error
            } catch {
                lastError = AppErrorMapper.map(error, operation: "intake.autosave")
            }
        }
    }

    /// Persists the latest scheduled value immediately and surfaces failures.
    func flush() throws {
        pendingTask?.cancel()
        pendingTask = nil
        try savePendingDraft()
    }

    func cancel() {
        pendingTask?.cancel()
        pendingTask = nil
        pendingDraft = nil
        lastError = nil
    }

    private func savePendingDraft() throws {
        guard let pendingDraft else { return }
        try repository.save(pendingDraft)
        self.pendingDraft = nil
        pendingTask = nil
        lastError = nil
    }
}
