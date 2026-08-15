import Foundation
import SwiftData

enum DataRestoreError: Error, Equatable, Sendable {
    case storeNotEmpty
    case mediaStoreNotEmpty
    case duplicateRecord(UUID)
    case unsupportedEntity(String)
    case missingField(entity: String, field: String)
    case invalidField(entity: String, field: String)
    case missingRelationship(entity: String, id: UUID)
}

struct DataRestoreSummary: Equatable, Sendable {
    let recordCount: Int
    let assetCount: Int
    let entityCounts: [String: Int]
}

@MainActor
struct DataBackupRestoreService {
    private let context: ModelContext
    private let mediaDirectories: BackupMediaDirectories?
    private let fileManager: FileManager

    init(
        context: ModelContext,
        mediaDirectories: BackupMediaDirectories? = try? .live(),
        fileManager: FileManager = .default
    ) {
        self.context = context
        self.mediaDirectories = mediaDirectories
        self.fileManager = fileManager
    }

    func preview(_ package: BackupPackage) -> DataRestoreSummary {
        DataRestoreSummary(
            recordCount: package.backup.records.count,
            assetCount: package.assets.count,
            entityCounts: Dictionary(grouping: package.backup.records, by: \.entity).mapValues(\.count)
        )
    }

    func restore(_ package: BackupPackage) throws -> DataRestoreSummary {
        try ensureEmptyStore()
        try ensureUniqueAndSupported(package.backup.records)
        let writtenAssets = try restoreAssets(package.assets)
        do {
            try insertRecords(package.backup.records)
            try context.save()
            return preview(package)
        } catch {
            context.rollback()
            writtenAssets.forEach { try? fileManager.removeItem(at: $0) }
            throw error
        }
    }

    private func ensureUniqueAndSupported(_ records: [BackupRecord]) throws {
        var ids = Set<UUID>()
        let supported = Set([
            "Client", "ClientDogRole", "Dog", "Intake", "TrainingGoal", "Exercise", "ExerciseVersion",
            "ExerciseLocalization", "TrainingTemplate", "TemplateVersion", "TemplateExercise", "ContentPack",
            "ScheduledSession", "Booking", "Attendance", "CompletedSession", "ExerciseSnapshot",
            "DogExerciseResult", "ClientReport", "TrainingPackage", "PackageTemplate", "PackageLedgerEntry", "Coupon"
        ])
        for record in records {
            guard supported.contains(record.entity) else { throw DataRestoreError.unsupportedEntity(record.entity) }
            guard ids.insert(record.id).inserted else { throw DataRestoreError.duplicateRecord(record.id) }
        }
    }

    private func ensureEmptyStore() throws {
        let counts = try [
            context.fetchCount(FetchDescriptor<ClientRecord>()), context.fetchCount(FetchDescriptor<ClientDogRoleRecord>()),
            context.fetchCount(FetchDescriptor<DogRecord>()), context.fetchCount(FetchDescriptor<IntakeRecordEntity>()),
            context.fetchCount(FetchDescriptor<TrainingGoalRecord>()), context.fetchCount(FetchDescriptor<ExerciseRecord>()),
            context.fetchCount(FetchDescriptor<ExerciseVersionRecord>()), context.fetchCount(FetchDescriptor<ExerciseLocalizationRecord>()),
            context.fetchCount(FetchDescriptor<TrainingTemplateRecord>()), context.fetchCount(FetchDescriptor<TemplateVersionRecord>()),
            context.fetchCount(FetchDescriptor<TemplateExerciseRecord>()), context.fetchCount(FetchDescriptor<ContentPackRecord>()),
            context.fetchCount(FetchDescriptor<ScheduledSessionRecord>()), context.fetchCount(FetchDescriptor<BookingRecord>()),
            context.fetchCount(FetchDescriptor<AttendanceRecord>()), context.fetchCount(FetchDescriptor<CompletedSessionRecord>()),
            context.fetchCount(FetchDescriptor<ExerciseSnapshotRecord>()), context.fetchCount(FetchDescriptor<DogExerciseResultRecord>()),
            context.fetchCount(FetchDescriptor<ClientReportRecord>()), context.fetchCount(FetchDescriptor<TrainingPackageRecord>()),
            context.fetchCount(FetchDescriptor<PackageTemplateRecord>()), context.fetchCount(FetchDescriptor<PackageLedgerEntryRecord>()),
            context.fetchCount(FetchDescriptor<CouponRecord>())
        ]
        guard counts.allSatisfy({ $0 == 0 }) else { throw DataRestoreError.storeNotEmpty }
    }

    private func restoreAssets(_ assets: [BackupAsset]) throws -> [URL] {
        guard !assets.isEmpty else { return [] }
        guard let mediaDirectories else { throw DataRestoreError.mediaStoreNotEmpty }
        let roots: [BackupAssetKind: URL] = [.dogPhoto: mediaDirectories.dogPhotos, .exerciseMedia: mediaDirectories.exerciseMedia]
        for root in roots.values where fileManager.fileExists(atPath: root.path) {
            let contents = try fileManager.contentsOfDirectory(atPath: root.path)
            guard contents.isEmpty else { throw DataRestoreError.mediaStoreNotEmpty }
        }
        var written: [URL] = []
        do {
            for asset in assets {
                guard DataBackupService.isSafe(relativePath: asset.relativePath),
                      asset.sha256 == DataBackupService.hash(asset.data),
                      let root = roots[asset.kind] else { throw DataBackupError.unsafeAssetPath }
                let destination = root.appending(path: asset.relativePath)
                try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                try asset.data.write(to: destination, options: [.atomic, .completeFileProtection])
                written.append(destination)
            }
            return written
        } catch {
            written.forEach { try? fileManager.removeItem(at: $0) }
            throw error
        }
    }

    private func insertRecords(_ records: [BackupRecord]) throws {
        let grouped = Dictionary(grouping: records, by: \.entity)
        var clients: [UUID: ClientRecord] = [:], dogs: [UUID: DogRecord] = [:]
        var roles: [UUID: ClientDogRoleRecord] = [:], intakes: [UUID: IntakeRecordEntity] = [:], goals: [UUID: TrainingGoalRecord] = [:]
        var exercises: [UUID: ExerciseRecord] = [:], versions: [UUID: ExerciseVersionRecord] = [:]
        var localizations: [UUID: ExerciseLocalizationRecord] = [:], templates: [UUID: TrainingTemplateRecord] = [:]
        var templateVersions: [UUID: TemplateVersionRecord] = [:], templateExercises: [UUID: TemplateExerciseRecord] = [:]
        var contentPacks: [UUID: ContentPackRecord] = [:], sessions: [UUID: ScheduledSessionRecord] = [:]
        var bookings: [UUID: BookingRecord] = [:], attendances: [UUID: AttendanceRecord] = [:]
        var completions: [UUID: CompletedSessionRecord] = [:], snapshots: [UUID: ExerciseSnapshotRecord] = [:]
        var results: [UUID: DogExerciseResultRecord] = [:], reports: [UUID: ClientReportRecord] = [:]
        var packageTemplates: [UUID: PackageTemplateRecord] = [:], packages: [UUID: TrainingPackageRecord] = [:]
        var ledgerEntries: [UUID: PackageLedgerEntryRecord] = [:], coupons: [UUID: CouponRecord] = [:]

        for r in grouped["Client", default: []] {
            let value = ClientRecord(id: r.id, displayName: try r.required("displayName"), createdAt: try r.date("createdAt"))
            value.email = r.fields["email"]; value.phone = r.fields["phone"]; value.addressStreet = r.fields["addressStreet"]
            value.addressPostalCode = r.fields["addressPostalCode"]; value.addressCity = r.fields["addressCity"]
            value.addressCountryCode = r.fields["addressCountryCode"]; value.privateNotes = r.fields["privateNotes"]
            value.isArchived = try r.bool("isArchived"); value.updatedAt = try r.date("updatedAt")
            clients[r.id] = value; context.insert(value)
        }
        for r in grouped["Dog", default: []] {
            let value = DogRecord(id: r.id, name: try r.required("name"), createdAt: try r.date("createdAt"))
            value.photoAssetID = r.fields["photoAssetID"]; value.birthDate = try r.optionalDate("birthDate"); value.breedText = r.fields["breedText"]
            value.sexRawValue = r.fields["sex"]; value.safetyFlagRawValues = try r.stringArray("safetyFlags")
            value.safetyPrivateNote = r.fields["safetyPrivateNote"]; value.isArchived = try r.bool("isArchived"); value.updatedAt = try r.date("updatedAt")
            dogs[r.id] = value; context.insert(value)
        }
        for r in grouped["Exercise", default: []] {
            let value = ExerciseRecord(id: r.id, originRawValue: try r.required("origin"))
            value.contentPackID = try r.optionalUUID("contentPackID"); value.currentVersionID = try r.optionalUUID("currentVersionID")
            value.categoryIDs = try r.uuidArray("categoryIDs"); value.isArchived = try r.bool("isArchived")
            exercises[r.id] = value; context.insert(value)
        }
        for r in grouped["TrainingTemplate", default: []] {
            let value = TrainingTemplateRecord(id: r.id); value.currentVersionID = try r.optionalUUID("currentVersionID"); value.isArchived = try r.bool("isArchived")
            templates[r.id] = value; context.insert(value)
        }
        for r in grouped["ContentPack", default: []] {
            let value = ContentPackRecord(id: r.id, semanticVersion: try r.required("semanticVersion"), titleKey: try r.required("titleKey"))
            value.author = try r.required("author"); value.licenseMetadata = try r.required("licenseMetadata"); value.minimumAppVersion = try r.required("minimumAppVersion")
            value.includedExerciseIDs = try r.uuidArray("includedExerciseIDs"); value.entitlementID = r.fields["entitlementID"]; value.checksum = try r.required("checksum")
            contentPacks[r.id] = value; context.insert(value)
        }
        for r in grouped["PackageTemplate", default: []] {
            let value = PackageTemplateRecord(id: r.id, name: try r.required("name"), units: try r.decimal("units"), price: try r.decimal("price"), currencyCode: try r.required("currencyCode"), createdAt: try r.date("createdAt"))
            value.unitTypeRawValue = try r.required("unitType"); value.isArchived = try r.bool("isArchived")
            packageTemplates[r.id] = value; context.insert(value)
        }
        for r in grouped["ExerciseVersion", default: []] {
            let exerciseID = try r.uuid("exerciseID")
            let value = ExerciseVersionRecord(id: r.id, exerciseID: exerciseID, versionNumber: try r.int("versionNumber"))
            value.durationMinutes = try r.optionalInt("durationMinutes"); value.difficultyRawValue = try r.required("difficulty")
            value.equipment = try r.stringArray("equipment"); value.safetyLevelRawValue = try r.required("safetyLevel")
            value.publishedAt = try r.optionalDate("publishedAt"); value.supersedesVersionID = try r.optionalUUID("supersedesVersionID"); value.exercise = try require(exercises, exerciseID, "ExerciseVersion")
            versions[r.id] = value; context.insert(value)
        }
        for r in grouped["ExerciseLocalization", default: []] {
            let versionID = try r.uuid("exerciseVersionID")
            let value = ExerciseLocalizationRecord(id: r.id, exerciseVersionID: versionID, localeIdentifier: try r.required("localeIdentifier"))
            value.title = try r.required("title"); value.goal = try r.required("goal"); value.setup = try r.required("setup"); value.steps = try r.stringArray("steps")
            value.successCriteria = try r.stringArray("successCriteria")
            value.commonErrors = ExerciseSupplementCodec.encode(problems: try r.stringArray("commonErrors"), measures: try r.stringArray("correctiveMeasures"))
            value.regression = try r.required("regression"); value.progression = try r.required("progression"); value.homework = try r.required("homework")
            value.safetyNotes = try r.required("safetyNotes"); value.reviewStatusRawValue = try r.required("reviewStatus"); value.exerciseVersion = try require(versions, versionID, "ExerciseLocalization")
            localizations[r.id] = value; context.insert(value)
        }
        for r in grouped["TemplateVersion", default: []] {
            let templateID = try r.uuid("templateID")
            let value = TemplateVersionRecord(id: r.id, templateID: templateID, versionNumber: try r.int("versionNumber"), title: try r.required("title"))
            value.targetDurationMinutes = try r.int("targetDurationMinutes"); value.audience = try r.required("audience"); value.trainerNotes = r.fields["trainerNotes"]
            value.publishedAt = try r.optionalDate("publishedAt"); value.supersedesVersionID = try r.optionalUUID("supersedesVersionID"); value.template = try require(templates, templateID, "TemplateVersion")
            templateVersions[r.id] = value; context.insert(value)
        }
        for r in grouped["TemplateExercise", default: []] {
            let templateVersionID = try r.uuid("templateVersionID"), exerciseVersionID = try r.uuid("exerciseVersionID")
            let value = TemplateExerciseRecord(id: r.id, templateVersionID: templateVersionID, exerciseVersionID: exerciseVersionID, sortOrder: try r.int("sortOrder"))
            value.plannedDurationMinutes = try r.optionalInt("plannedDurationMinutes"); value.trainerInstruction = r.fields["trainerInstruction"]
            value.templateVersion = try require(templateVersions, templateVersionID, "TemplateExercise"); value.exerciseVersion = try require(versions, exerciseVersionID, "TemplateExercise")
            templateExercises[r.id] = value; context.insert(value)
        }
        for r in grouped["Intake", default: []] {
            let dogID = try r.uuid("dogID"); let value = IntakeRecordEntity(id: r.id, dogID: dogID, revision: try r.int("revision"), occurredAt: try r.date("occurredAt"))
            value.reason = try r.required("reason"); value.environment = try r.required("environment"); value.history = try r.required("history")
            value.knownTriggers = try r.required("knownTriggers"); value.previousTraining = try r.required("previousTraining"); value.healthNotes = try r.required("healthNotes")
            value.desiredOutcome = try r.required("desiredOutcome"); value.privateNotes = r.fields["privateNotes"]; value.dog = try require(dogs, dogID, "Intake")
            intakes[r.id] = value; context.insert(value)
        }
        for r in grouped["TrainingGoal", default: []] {
            let dogID = try r.uuid("dogID"); let value = TrainingGoalRecord(id: r.id, dogID: dogID, title: try r.required("title"), startedAt: try r.date("startedAt"))
            value.statusRawValue = try r.required("status"); value.targetDescription = try r.required("targetDescription"); value.completedAt = try r.optionalDate("completedAt"); value.exerciseID = try r.optionalUUID("exerciseID")
            value.dog = try require(dogs, dogID, "TrainingGoal"); if let id = value.exerciseID { value.exercise = exercises[id] }
            goals[r.id] = value; context.insert(value)
        }
        for r in grouped["ClientDogRole", default: []] {
            let clientID = try r.uuid("clientID"), dogID = try r.uuid("dogID")
            let value = ClientDogRoleRecord(id: r.id, clientID: clientID, dogID: dogID, roleRawValue: try r.required("role"), isPrimaryContact: try r.bool("isPrimaryContact"))
            value.client = try require(clients, clientID, "ClientDogRole"); value.dog = try require(dogs, dogID, "ClientDogRole")
            roles[r.id] = value; context.insert(value)
        }
        for r in grouped["TrainingPackage", default: []] {
            let dogID = try r.uuid("dogID")
            let value = TrainingPackageRecord(id: r.id, dogID: dogID, name: try r.required("name"), initialUnits: try r.decimal("initialUnits"), purchasedAt: try r.date("purchasedAt"))
            value.clientID = try r.optionalUUID("clientID"); value.packageTemplateID = try r.optionalUUID("packageTemplateID"); value.unitTypeRawValue = try r.required("unitType")
            value.expiresAt = try r.optionalDate("expiresAt"); value.paymentStatusRawValue = try r.required("paymentStatus"); value.priceSnapshot = try r.optionalDecimal("priceSnapshot")
            value.currencyCode = r.fields["currencyCode"]; value.isClosed = try r.bool("isClosed"); value.dog = dogs[dogID]
            if let id = value.clientID { value.client = clients[id] }; if let id = value.packageTemplateID { value.packageTemplate = packageTemplates[id] }
            packages[r.id] = value; context.insert(value)
        }
        for r in grouped["ScheduledSession", default: []] {
            let value = ScheduledSessionRecord(id: r.id, title: try r.required("title"), startAt: try r.date("startAt"), durationMinutes: try r.int("durationMinutes"))
            value.locationText = r.fields["locationText"]; value.kindRawValue = try r.required("kind"); value.statusRawValue = try r.required("status")
            value.templateVersionID = try r.optionalUUID("templateVersionID"); value.calendarEventIdentifier = r.fields["calendarEventIdentifier"]
            value.labels = try r.stringArray("labels"); value.packageUnitsPerAttendee = try r.decimal("packageUnitsPerAttendee")
            if let id = value.templateVersionID { value.templateVersion = templateVersions[id] }; sessions[r.id] = value; context.insert(value)
        }
        for r in grouped["Booking", default: []] {
            let sessionID = try r.uuid("sessionID"), dogID = try r.uuid("dogID")
            let value = BookingRecord(id: r.id, sessionID: sessionID, dogID: dogID); value.bookingStatusRawValue = try r.required("bookingStatus")
            value.expectedPackageID = try r.optionalUUID("expectedPackageID"); value.session = try require(sessions, sessionID, "Booking"); value.dog = try require(dogs, dogID, "Booking")
            if let id = value.expectedPackageID { value.expectedPackage = packages[id] }; bookings[r.id] = value; context.insert(value)
        }
        for r in grouped["Attendance", default: []] {
            let bookingID = try r.uuid("bookingID")
            let value = AttendanceRecord(id: r.id, bookingID: bookingID, statusRawValue: try r.required("status"), checkedAt: try r.date("checkedAt"))
            value.packagePolicyRawValue = try r.required("packagePolicy"); value.completionRevision = try r.int("completionRevision"); value.isActiveRevision = try r.bool("isActiveRevision")
            value.booking = try require(bookings, bookingID, "Attendance"); attendances[r.id] = value; context.insert(value)
        }
        for r in grouped["CompletedSession", default: []] {
            let sessionID = try r.uuid("sessionID")
            let value = CompletedSessionRecord(id: r.id, sessionID: sessionID, completedAt: try r.date("completedAt"), completionToken: try r.uuid("completionToken"), revision: try r.int("revision"))
            value.requestFingerprint = try r.required("requestFingerprint"); value.supersedesCompletedSessionID = try r.optionalUUID("supersedesCompletedSessionID")
            value.correctionReason = r.fields["correctionReason"]; value.isActiveRevision = try r.bool("isActiveRevision"); value.generalNotes = r.fields["generalNotes"]
            value.defaultOutcomeRawValue = try r.required("defaultOutcome"); value.session = try require(sessions, sessionID, "CompletedSession")
            completions[r.id] = value; context.insert(value)
        }
        for r in grouped["ExerciseSnapshot", default: []] {
            let completionID = try r.uuid("completedSessionID")
            let value = ExerciseSnapshotRecord(id: r.id, completedSessionID: completionID, sourceExerciseID: try r.uuid("sourceExerciseID"), sourceExerciseVersionID: try r.uuid("sourceExerciseVersionID"))
            value.localeIdentifier = try r.required("localeIdentifier"); value.title = try r.required("title"); value.goal = try r.required("goal"); value.setup = try r.required("setup")
            value.steps = try r.stringArray("steps"); value.successCriteria = try r.stringArray("successCriteria"); value.homework = try r.required("homework"); value.safetyNotes = try r.required("safetyNotes")
            value.completedSession = try require(completions, completionID, "ExerciseSnapshot"); snapshots[r.id] = value; context.insert(value)
        }
        for r in grouped["DogExerciseResult", default: []] {
            let attendanceID = try r.uuid("attendanceID"), snapshotID = try r.uuid("exerciseSnapshotID")
            let value = DogExerciseResultRecord(id: r.id, attendanceID: attendanceID, exerciseSnapshotID: snapshotID)
            value.goalID = try r.optionalUUID("goalID"); value.outcomeRawValue = try r.required("outcome"); value.wasPerformed = try r.bool("wasPerformed")
            value.trainerPrivateNote = r.fields["trainerPrivateNote"]; value.clientFacingNote = r.fields["clientFacingNote"]
            value.attendance = try require(attendances, attendanceID, "DogExerciseResult"); value.exerciseSnapshot = try require(snapshots, snapshotID, "DogExerciseResult")
            if let id = value.goalID { value.goal = goals[id] }; results[r.id] = value; context.insert(value)
        }
        for r in grouped["ClientReport", default: []] {
            let dogID = try r.uuid("dogID"), completionID = try r.uuid("completedSessionID")
            let value = ClientReportRecord(id: r.id, dogID: dogID, completedSessionID: completionID, localeIdentifier: try r.required("localeIdentifier"))
            value.statusRawValue = try r.required("status"); value.revision = try r.int("revision"); value.supersedesReportID = try r.optionalUUID("supersedesReportID")
            value.body = try r.required("body"); value.generatedAt = try r.date("generatedAt"); value.approvedAt = try r.optionalDate("approvedAt"); value.exportedAt = try r.optionalDate("exportedAt")
            value.dog = try require(dogs, dogID, "ClientReport"); value.completedSession = try require(completions, completionID, "ClientReport")
            reports[r.id] = value; context.insert(value)
        }
        for r in grouped["PackageLedgerEntry", default: []] {
            let packageID = try r.uuid("packageID")
            let value = PackageLedgerEntryRecord(id: r.id, packageID: packageID, kindRawValue: try r.required("kind"), unitDelta: try r.decimal("unitDelta"), createdAt: try r.date("createdAt"))
            value.moneyDelta = try r.optionalDecimal("moneyDelta"); value.currencyCode = r.fields["currencyCode"]; value.attendanceID = try r.optionalUUID("attendanceID")
            value.reversesEntryID = try r.optionalUUID("reversesEntryID"); value.reason = r.fields["reason"]; value.package = try require(packages, packageID, "PackageLedgerEntry")
            if let id = value.attendanceID { value.attendance = attendances[id] }
            ledgerEntries[r.id] = value; context.insert(value)
        }
        for value in ledgerEntries.values { if let id = value.reversesEntryID { value.reversesEntry = ledgerEntries[id] } }
        for r in grouped["Coupon", default: []] {
            let value = CouponRecord(id: r.id, code: try r.required("code"), kindRawValue: try r.required("kind"), amount: try r.decimal("amount"), issuedAt: try r.date("issuedAt"))
            value.currencyCode = r.fields["currencyCode"]; value.expiresAt = try r.optionalDate("expiresAt"); value.redeemedAt = try r.optionalDate("redeemedAt"); value.redeemedPackageID = try r.optionalUUID("redeemedPackageID")
            if let id = value.redeemedPackageID { value.redeemedPackage = packages[id] }; coupons[r.id] = value; context.insert(value)
        }

        for value in clients.values { value.dogRoles = roles.values.filter { $0.clientID == value.id }; value.packages = packages.values.filter { $0.clientID == value.id } }
        for value in dogs.values {
            value.clientRoles = roles.values.filter { $0.dogID == value.id }; value.intakeRecords = intakes.values.filter { $0.dogID == value.id }
            value.trainingGoals = goals.values.filter { $0.dogID == value.id }; value.bookings = bookings.values.filter { $0.dogID == value.id }
            value.packages = packages.values.filter { $0.dogID == value.id }; value.reports = reports.values.filter { $0.dogID == value.id }
        }
        for value in exercises.values { value.versions = versions.values.filter { $0.exerciseID == value.id }; value.contentPack = value.contentPackID.flatMap { contentPacks[$0] } }
        for value in versions.values { value.localizations = localizations.values.filter { $0.exerciseVersionID == value.id } }
        for value in templates.values { value.versions = templateVersions.values.filter { $0.templateID == value.id } }
        for value in templateVersions.values { value.exercises = templateExercises.values.filter { $0.templateVersionID == value.id } }
        for value in contentPacks.values { value.exercises = exercises.values.filter { $0.contentPackID == value.id } }
        for value in sessions.values { value.bookings = bookings.values.filter { $0.sessionID == value.id }; value.completedSession = completions.values.first { $0.sessionID == value.id && $0.isActiveRevision } }
        for value in bookings.values { value.attendance = attendances.values.first { $0.bookingID == value.id && $0.isActiveRevision } }
        for value in attendances.values { value.results = results.values.filter { $0.attendanceID == value.id }; value.ledgerEntries = ledgerEntries.values.filter { $0.attendanceID == value.id } }
        for value in completions.values { value.exerciseSnapshots = snapshots.values.filter { $0.completedSessionID == value.id }; value.reports = reports.values.filter { $0.completedSessionID == value.id } }
        for value in snapshots.values { value.results = results.values.filter { $0.exerciseSnapshotID == value.id } }
        for value in packageTemplates.values { value.packages = packages.values.filter { $0.packageTemplateID == value.id } }
        for value in packages.values { value.ledgerEntries = ledgerEntries.values.filter { $0.packageID == value.id } }
        _ = coupons
    }

    private func require<T>(_ values: [UUID: T], _ id: UUID, _ entity: String) throws -> T {
        guard let value = values[id] else { throw DataRestoreError.missingRelationship(entity: entity, id: id) }
        return value
    }
}

private extension BackupRecord {
    func required(_ key: String) throws -> String {
        guard let value = fields[key] else { throw DataRestoreError.missingField(entity: entity, field: key) }
        return value
    }

    func uuid(_ key: String) throws -> UUID {
        guard let value = UUID(uuidString: try required(key)) else { throw DataRestoreError.invalidField(entity: entity, field: key) }
        return value
    }

    func optionalUUID(_ key: String) throws -> UUID? {
        guard let raw = fields[key] else { return nil }
        guard let value = UUID(uuidString: raw) else { throw DataRestoreError.invalidField(entity: entity, field: key) }
        return value
    }

    func int(_ key: String) throws -> Int {
        guard let value = Int(try required(key)) else { throw DataRestoreError.invalidField(entity: entity, field: key) }
        return value
    }

    func optionalInt(_ key: String) throws -> Int? {
        guard let raw = fields[key] else { return nil }
        guard let value = Int(raw) else { throw DataRestoreError.invalidField(entity: entity, field: key) }
        return value
    }

    func bool(_ key: String) throws -> Bool {
        switch try required(key) { case "true": return true; case "false": return false; default: throw DataRestoreError.invalidField(entity: entity, field: key) }
    }

    func decimal(_ key: String) throws -> Decimal {
        guard let value = Decimal(string: try required(key), locale: Locale(identifier: "en_US_POSIX")) else { throw DataRestoreError.invalidField(entity: entity, field: key) }
        return value
    }

    func optionalDecimal(_ key: String) throws -> Decimal? {
        guard let raw = fields[key] else { return nil }
        guard let value = Decimal(string: raw, locale: Locale(identifier: "en_US_POSIX")) else { throw DataRestoreError.invalidField(entity: entity, field: key) }
        return value
    }

    func date(_ key: String) throws -> Date {
        guard let value = Self.parseDate(try required(key)) else { throw DataRestoreError.invalidField(entity: entity, field: key) }
        return value
    }

    func optionalDate(_ key: String) throws -> Date? {
        guard let raw = fields[key] else { return nil }
        guard let value = Self.parseDate(raw) else { throw DataRestoreError.invalidField(entity: entity, field: key) }
        return value
    }

    func stringArray(_ key: String) throws -> [String] {
        guard let data = fields[key]?.data(using: .utf8), let value = try? JSONDecoder().decode([String].self, from: data) else {
            throw DataRestoreError.invalidField(entity: entity, field: key)
        }
        return value
    }

    func uuidArray(_ key: String) throws -> [UUID] {
        let strings = try stringArray(key)
        let values = strings.compactMap(UUID.init(uuidString:))
        guard values.count == strings.count else { throw DataRestoreError.invalidField(entity: entity, field: key) }
        return values
    }

    static func parseDate(_ value: String) -> Date? {
        if let date = ISO8601DateFormatter().date(from: value) { return date }
        return posixDateFormatter.date(from: value)
    }

    static let posixDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        return formatter
    }()
}
