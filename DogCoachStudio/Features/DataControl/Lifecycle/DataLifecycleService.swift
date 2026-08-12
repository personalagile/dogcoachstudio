import Foundation
import SwiftData

struct DeletionPreview: Equatable, Sendable {
    let dogID: UUID
    let roles: Int
    let intakes: Int
    let goals: Int
    let bookings: Int
    let packages: Int
    let reports: Int

    var dependentRecordCount: Int { roles + intakes + goals + bookings + packages + reports }
    var containsBusinessHistory: Bool { bookings > 0 || packages > 0 || reports > 0 }
    var exportRecommended: Bool { dependentRecordCount > 0 }
}

enum DataLifecycleError: Error, Equatable, Sendable {
    case dogNotFound
    case exportConfirmationRequired
    case archiveRequiredForBusinessHistory
}

@MainActor
struct DataLifecycleService {
    let context: ModelContext

    func previewDogDeletion(id: UUID) throws -> DeletionPreview {
        guard try dog(id: id) != nil else { throw DataLifecycleError.dogNotFound }
        return DeletionPreview(
            dogID: id,
            roles: try context.fetchCount(FetchDescriptor<ClientDogRoleRecord>(predicate: #Predicate { $0.dogID == id })),
            intakes: try context.fetchCount(FetchDescriptor<IntakeRecordEntity>(predicate: #Predicate { $0.dogID == id })),
            goals: try context.fetchCount(FetchDescriptor<TrainingGoalRecord>(predicate: #Predicate { $0.dogID == id })),
            bookings: try context.fetchCount(FetchDescriptor<BookingRecord>(predicate: #Predicate { $0.dogID == id })),
            packages: try context.fetchCount(FetchDescriptor<TrainingPackageRecord>(predicate: #Predicate { $0.dogID == id })),
            reports: try context.fetchCount(FetchDescriptor<ClientReportRecord>(predicate: #Predicate { $0.dogID == id }))
        )
    }

    func archiveDog(id: UUID) throws {
        guard let dog = try dog(id: id) else { throw DataLifecycleError.dogNotFound }
        dog.isArchived = true
        dog.updatedAt = .now
        try context.save()
    }

    func permanentlyDeleteDog(id: UUID, exportConfirmed: Bool, allowBusinessHistoryDeletion: Bool = false) throws {
        guard let dog = try dog(id: id) else { throw DataLifecycleError.dogNotFound }
        let preview = try previewDogDeletion(id: id)
        if preview.exportRecommended && !exportConfirmed { throw DataLifecycleError.exportConfirmationRequired }
        if preview.containsBusinessHistory && !allowBusinessHistoryDeletion { throw DataLifecycleError.archiveRequiredForBusinessHistory }

        let bookings = try context.fetch(FetchDescriptor<BookingRecord>(predicate: #Predicate { $0.dogID == id }))
        let bookingIDs = Set(bookings.map(\.id))
        let attendances = try context.fetch(FetchDescriptor<AttendanceRecord>()).filter { bookingIDs.contains($0.bookingID) }
        let attendanceIDs = Set(attendances.map(\.id))
        let packages = try context.fetch(FetchDescriptor<TrainingPackageRecord>(predicate: #Predicate { $0.dogID == id }))
        let packageIDs = Set(packages.map(\.id))
        try context.fetch(FetchDescriptor<DogExerciseResultRecord>()).filter { attendanceIDs.contains($0.attendanceID) }.forEach(context.delete)
        try context.fetch(FetchDescriptor<PackageLedgerEntryRecord>()).filter { packageIDs.contains($0.packageID) || $0.attendanceID.map(attendanceIDs.contains) == true }.forEach(context.delete)
        try context.fetch(FetchDescriptor<CouponRecord>()).filter { $0.redeemedPackageID.map(packageIDs.contains) == true }.forEach { $0.redeemedPackage = nil; $0.redeemedPackageID = nil }
        attendances.forEach(context.delete)
        bookings.forEach(context.delete)
        packages.forEach(context.delete)
        try context.fetch(FetchDescriptor<ClientReportRecord>(predicate: #Predicate { $0.dogID == id })).forEach(context.delete)
        try context.fetch(FetchDescriptor<IntakeRecordEntity>(predicate: #Predicate { $0.dogID == id })).forEach(context.delete)
        try context.fetch(FetchDescriptor<TrainingGoalRecord>(predicate: #Predicate { $0.dogID == id })).forEach(context.delete)
        try context.fetch(FetchDescriptor<ClientDogRoleRecord>(predicate: #Predicate { $0.dogID == id })).forEach(context.delete)
        context.delete(dog)
        try context.save()
    }

    private func dog(id: UUID) throws -> DogRecord? {
        var descriptor = FetchDescriptor<DogRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
