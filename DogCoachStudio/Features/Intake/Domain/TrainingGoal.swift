import Foundation

enum TrainingGoalStatus: String, CaseIterable, Codable, Equatable, Sendable {
    case planned
    case active
    case paused
    case achieved
    case abandoned
}

struct TrainingGoal: Identifiable, Equatable, Sendable {
    let id: UUID
    let dogID: UUID
    var title: String
    var status: TrainingGoalStatus
    var targetDescription: String
    var startedAt: Date
    var completedAt: Date?
    var exerciseID: UUID?

    init(
        id: UUID = UUID(),
        dogID: UUID,
        title: String,
        status: TrainingGoalStatus = .planned,
        targetDescription: String = "",
        startedAt: Date = .now,
        completedAt: Date? = nil,
        exerciseID: UUID? = nil
    ) {
        self.id = id
        self.dogID = dogID
        self.title = title
        self.status = status
        self.targetDescription = targetDescription
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.exerciseID = exerciseID
    }

    mutating func transition(to newStatus: TrainingGoalStatus, at date: Date) {
        status = newStatus
        completedAt = switch newStatus {
        case .achieved, .abandoned: date
        case .planned, .active, .paused: nil
        }
    }
}
