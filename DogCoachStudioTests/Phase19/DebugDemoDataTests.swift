import Foundation
import SwiftData
import Testing
@testable import DogCoachStudio

@Suite("Phase 19 debug demo data")
struct DebugDemoDataTests {
    private let now = Date(timeIntervalSince1970: 1_786_737_600)

    @Test("Rich fixture populates every primary area including finance")
    @MainActor
    func richFixture() throws {
        let container = try ModelContainerFactory.makeInMemory()
        try DemoDataSeeder.seedIfNeeded(
            context: container.mainContext,
            clock: FixedAppClock(date: now),
            uuidGenerator: SystemUUIDGenerator()
        )
        let context = container.mainContext

        #expect(try context.fetch(FetchDescriptor<ClientRecord>()).count == 3)
        #expect(try context.fetch(FetchDescriptor<DogRecord>()).count == 4)
        #expect(try context.fetch(FetchDescriptor<TrainingGoalRecord>()).count == 4)
        #expect(try context.fetch(FetchDescriptor<ExerciseRecord>()).count == 3)
        #expect(try context.fetch(FetchDescriptor<TrainingTemplateRecord>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<PackageTemplateRecord>()).count == 4)
        #expect(try context.fetch(FetchDescriptor<TrainingPackageRecord>()).count == 8)

        let sessions = try SwiftDataScheduledSessionRepository(context: context, uuid: SystemUUIDGenerator()).list()
        #expect(sessions.count == 5)
        #expect(sessions.contains(where: { $0.isEvaluated }))
        #expect(sessions.contains(where: { !$0.isEvaluated && $0.startAt < now }))

        let finance = FinanceRepository(context: context)
        let month = try finance.snapshot(period: .month, currencyCode: "EUR", now: now)
        let all = try finance.snapshot(period: .all, currencyCode: "EUR", now: now)
        #expect(month.salesCount == 3)
        #expect(month.totalRevenue == 530)
        #expect(all.salesCount == 7)
        #expect(all.totalRevenue == 1_235)
        #expect(all.packages.count == 3)
    }

    @Test("Seeder is idempotent and does not enter a real workspace")
    @MainActor
    func seedingBoundaries() throws {
        let demo = try ModelContainerFactory.makeInMemory()
        let seed = {
            try DemoDataSeeder.seedIfNeeded(
                context: demo.mainContext,
                clock: FixedAppClock(date: now),
                uuidGenerator: SystemUUIDGenerator()
            )
        }
        try seed()
        let firstCounts = try counts(demo.mainContext)
        try seed()
        #expect(try counts(demo.mainContext) == firstCounts)

        let real = try ModelContainerFactory.makeInMemory()
        real.mainContext.insert(ClientRecord(displayName: "Real client"))
        try real.mainContext.save()
        try DemoDataSeeder.seedIfNeeded(
            context: real.mainContext,
            clock: FixedAppClock(date: now),
            uuidGenerator: SystemUUIDGenerator()
        )
        #expect(try real.mainContext.fetch(FetchDescriptor<ClientRecord>()).map(\.displayName) == ["Real client"])
        #expect(try real.mainContext.fetch(FetchDescriptor<PackageLedgerEntryRecord>()).isEmpty)
    }

    @Test("Automatic live seeding is compiled only for Debug")
    func releaseGuard() throws {
        let source = try String(contentsOf: projectFile("DogCoachStudio/App/AppEnvironment.swift"), encoding: .utf8)
        let liveBody = try #require(source.components(separatedBy: "static func preview()").first)
        let debugStart = try #require(liveBody.range(of: "#if DEBUG"))
        let debugEnd = try #require(liveBody.range(of: "#endif", range: debugStart.lowerBound..<liveBody.endIndex))
        let guardedBlock = liveBody[debugStart.lowerBound..<debugEnd.upperBound]
        #expect(guardedBlock.contains("DemoDataSeeder.seedIfNeeded"))
        #expect(!liveBody[liveBody.startIndex..<debugStart.lowerBound].contains("DemoDataSeeder.seedIfNeeded"))
        #expect(!liveBody[debugEnd.upperBound..<liveBody.endIndex].contains("DemoDataSeeder.seedIfNeeded"))
    }

    @MainActor
    private func counts(_ context: ModelContext) throws -> [Int] {
        [
            try context.fetch(FetchDescriptor<ClientRecord>()).count,
            try context.fetch(FetchDescriptor<DogRecord>()).count,
            try context.fetch(FetchDescriptor<ScheduledSessionRecord>()).count,
            try context.fetch(FetchDescriptor<TrainingPackageRecord>()).count,
            try context.fetch(FetchDescriptor<PackageLedgerEntryRecord>()).count
        ]
    }

    private func projectFile(_ relativePath: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: relativePath)
    }
}
