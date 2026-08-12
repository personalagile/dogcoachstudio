import Foundation
import SwiftData

@MainActor
final class ReportRepository {
    private let context: ModelContext
    private let clock: any AppClock
    init(context: ModelContext, clock: any AppClock) { self.context = context; self.clock = clock }

    func approve(reportID: UUID) throws { let report = try require(reportID); report.statusRawValue = "approved"; report.approvedAt = clock.now(); try context.save() }
    func markExported(reportID: UUID) throws { let report = try require(reportID); guard report.statusRawValue == "approved", report.approvedAt != nil else { throw ReportApprovalError.approvalRequired }; report.exportedAt = clock.now(); try context.save() }
    func requireApproved(reportID: UUID) throws -> ClientReportRecord { let report = try require(reportID); guard report.statusRawValue == "approved", report.approvedAt != nil else { throw ReportApprovalError.approvalRequired }; return report }
    private func require(_ id: UUID) throws -> ClientReportRecord { guard let report = try context.fetch(FetchDescriptor<ClientReportRecord>()).first(where: { $0.id == id }) else { throw ReportApprovalError.reportNotFound }; return report }
}
