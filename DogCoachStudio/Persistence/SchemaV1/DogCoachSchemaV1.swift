import Foundation
import SwiftData

enum DogCoachSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            ClientRecord.self,
            ClientDogRoleRecord.self,
            DogRecord.self,
            IntakeRecordEntity.self,
            TrainingGoalRecord.self,
            ExerciseRecord.self,
            ExerciseVersionRecord.self,
            ExerciseLocalizationRecord.self,
            TrainingTemplateRecord.self,
            TemplateVersionRecord.self,
            TemplateExerciseRecord.self,
            ScheduledSessionRecord.self,
            BookingRecord.self,
            AttendanceRecord.self,
            CompletedSessionRecord.self,
            ExerciseSnapshotRecord.self,
            DogExerciseResultRecord.self,
            TrainingPackageRecord.self,
            PackageLedgerEntryRecord.self,
            CouponRecord.self,
            ClientReportRecord.self,
            ContentPackRecord.self
        ]
    }
}

enum DogCoachMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [DogCoachSchemaV2.self] }
    static var stages: [MigrationStage] { [] }
}
