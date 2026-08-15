import Foundation
import SwiftData

@MainActor
enum DemoDataSeeder {
    private static let richDemoMarkerID = id(1_999)

    static func seedMinimalPeopleIfNeeded(
        context: ModelContext,
        clock: any AppClock,
        uuidGenerator: any UUIDGenerating
    ) throws {
        var descriptor = FetchDescriptor<ClientRecord>()
        descriptor.fetchLimit = 1
        guard try context.fetch(descriptor).isEmpty else { return }

        let createdAt = clock.now()
        let client = ClientRecord(
            id: uuidGenerator.makeUUID(),
            displayName: String(localized: "Demo client", comment: "Name of the fictional Phase 1 demo client"),
            createdAt: createdAt
        )
        let dog = DogRecord(
            id: uuidGenerator.makeUUID(),
            name: String(localized: "Demo dog", comment: "Name of the fictional Phase 1 demo dog"),
            createdAt: createdAt
        )
        let role = ClientDogRoleRecord(
            id: uuidGenerator.makeUUID(),
            clientID: client.id,
            dogID: dog.id,
            isPrimaryContact: true
        )
        role.client = client
        role.dog = dog
        client.dogRoles = [role]
        dog.clientRoles = [role]
        try SchemaV1Validators.validate(role)
        context.insert(client)
        context.insert(dog)
        context.insert(role)
        try context.save()
    }

    static func seedIfNeeded(
        context: ModelContext,
        clock: any AppClock,
        uuidGenerator _: any UUIDGenerating
    ) throws {
        let existingClients = try context.fetch(FetchDescriptor<ClientRecord>())
        if existingClients.contains(where: { $0.id == richDemoMarkerID }) { return }

        let localizedLegacyName = String(localized: "Demo client", comment: "Name of the fictional Phase 1 demo client")
        guard existingClients.isEmpty || existingClients.contains(where: { $0.displayName == localizedLegacyName }) else {
            return
        }

        let now = clock.now()
        let primaryClient: ClientRecord
        let primaryDog: DogRecord
        if let legacyClient = existingClients.first(where: { $0.displayName == localizedLegacyName }) {
            primaryClient = legacyClient
            primaryDog = try context.fetch(FetchDescriptor<DogRecord>()).first
                ?? makeDog(id: id(2_001), name: "Milo", breed: "Labrador mix", sex: "male", birthDate: date(years: -4, from: now))
            if primaryDog.modelContext == nil { context.insert(primaryDog) }
        } else {
            primaryClient = makeClient(id: id(1_001), name: localizedLegacyName, email: "anna@example.invalid", phone: "+49 30 5550101", city: "Berlin", country: "DE", createdAt: date(months: -10, from: now))
            primaryDog = makeDog(
                id: id(2_001),
                name: String(localized: "Demo dog", comment: "Name of the fictional Phase 1 demo dog"),
                breed: "Labrador mix",
                sex: "male",
                birthDate: date(years: -4, from: now)
            )
            context.insert(primaryClient)
            context.insert(primaryDog)
        }

        let secondClient = makeClient(id: id(1_002), name: "Luis García", email: "luis@example.invalid", phone: "+34 91 555 0102", city: "Madrid", country: "ES", createdAt: date(months: -7, from: now))
        let thirdClient = makeClient(id: richDemoMarkerID, name: "Camille Martin", email: "camille@example.invalid", phone: "+33 1 55 50 10 03", city: "Lyon", country: "FR", createdAt: date(months: -5, from: now))
        let luna = makeDog(id: id(2_002), name: "Luna", breed: "Border Collie", sex: "female", birthDate: date(years: -3, from: now))
        let charlie = makeDog(id: id(2_003), name: "Charlie", breed: "Mixed breed", sex: "unknown", birthDate: date(years: -6, from: now))
        let nala = makeDog(id: id(2_004), name: "Nala", breed: "Australian Shepherd", sex: "female", birthDate: date(years: -2, from: now))
        context.insert(secondClient)
        context.insert(thirdClient)
        context.insert(luna)
        context.insert(charlie)
        context.insert(nala)

        link(primaryClient, to: primaryDog, roleID: id(3_001), context: context)
        link(secondClient, to: luna, roleID: id(3_002), context: context)
        link(secondClient, to: charlie, roleID: id(3_003), context: context)
        link(thirdClient, to: nala, roleID: id(3_004), context: context)

        seedIntakesAndGoals(dogs: [primaryDog, luna, charlie, nala], now: now, context: context)
        let catalog = seedCatalog(now: now, context: context)
        let packages = seedPackages(
            clients: [primaryClient, secondClient, thirdClient],
            dogs: [primaryDog, luna, charlie, nala],
            now: now,
            context: context
        )
        seedSessions(dogs: [primaryDog, luna, charlie, nala], packages: packages, catalog: catalog, now: now, context: context)
        try context.save()
    }

    private static func seedIntakesAndGoals(dogs: [DogRecord], now: Date, context: ModelContext) {
        let intake = IntakeRecordEntity(id: id(4_001), dogID: dogs[0].id, occurredAt: date(months: -5, from: now))
        intake.reason = "Loose-leash walking and calm greetings"
        intake.environment = "Urban walks and group classes"
        intake.history = "Friendly and highly food motivated"
        intake.desiredOutcome = "Walk calmly past people and dogs"
        intake.privateNotes = "SAMPLE DATA — trainer-only observation"
        intake.dog = dogs[0]
        context.insert(intake)
        dogs[0].intakeRecords = [intake]

        let goals = [
            goal(id: id(4_101), dog: dogs[0], title: "Loose-leash walking", status: "active", target: "Ten calm steps with a loose lead", now: now),
            goal(id: id(4_102), dog: dogs[1], title: "Reliable recall", status: "active", target: "Return promptly around moderate distraction", now: now),
            goal(id: id(4_103), dog: dogs[2], title: "Settle on a mat", status: "planned", target: "Relax for five minutes in a café", now: now),
            goal(id: id(4_104), dog: dogs[3], title: "Calm greetings", status: "achieved", target: "Four paws stay on the floor", now: now)
        ]
        goals.forEach(context.insert)
        for dog in dogs { dog.trainingGoals = goals.filter { $0.dogID == dog.id } }
    }

    private static func seedCatalog(now: Date, context: ModelContext) -> (template: TemplateVersionRecord, versions: [ExerciseVersionRecord]) {
        let definitions: [(String, String, [String], [String])] = [
            ("Name response", "The dog turns toward the trainer after hearing its name.", ["Say the name once", "Mark eye contact", "Reward close to the trainer"], ["Four of five repetitions succeed", "Response occurs within two seconds"]),
            ("Loose-leash steps", "Build short sequences without tension on the lead.", ["Start in a quiet area", "Reward beside the leg", "Add one step at a time"], ["Lead stays loose for ten steps", "Dog can reorient after distraction"]),
            ("Settle on a mat", "Teach a portable resting behavior.", ["Place the mat", "Reward voluntary contact", "Build duration gradually"], ["Dog lies down voluntarily", "Dog remains relaxed for two minutes"])
        ]
        var versions: [ExerciseVersionRecord] = []
        for (index, definition) in definitions.enumerated() {
            let exercise = ExerciseRecord(id: id(5_001 + index))
            let version = ExerciseVersionRecord(id: id(5_101 + index), exerciseID: exercise.id)
            version.durationMinutes = 10
            version.difficultyRawValue = index == 0 ? "foundation" : "everyday"
            version.equipment = index == 1 ? ["Lead", "Treats"] : ["Treats"]
            version.publishedAt = date(months: -6, from: now)
            version.exercise = exercise
            exercise.currentVersionID = version.id
            exercise.versions = [version]
            let localization = ExerciseLocalizationRecord(id: id(5_201 + index), exerciseVersionID: version.id, localeIdentifier: "en")
            localization.title = definition.0
            localization.goal = definition.1
            localization.setup = "Use a low-distraction environment and small rewards."
            localization.steps = definition.2
            localization.successCriteria = definition.3
            localization.commonErrors = ExerciseSupplementCodec.encode(
                problems: ["Criteria increase too quickly", "Reward arrives too late"],
                measures: ["Reduce distraction or duration", "Mark the desired behavior earlier"]
            )
            localization.homework = "Practise two short sets on three days this week."
            localization.safetyNotes = "Stop if the dog shows stress or discomfort."
            localization.reviewStatusRawValue = "approved"
            localization.exerciseVersion = version
            version.localizations = [localization]
            context.insert(exercise)
            context.insert(version)
            context.insert(localization)
            versions.append(version)
        }

        let template = TrainingTemplateRecord(id: id(5_301))
        let templateVersion = TemplateVersionRecord(id: id(5_302), templateID: template.id, title: "Everyday foundations")
        templateVersion.targetDurationMinutes = 45
        templateVersion.audience = "Small group"
        templateVersion.publishedAt = date(months: -4, from: now)
        templateVersion.template = template
        template.currentVersionID = templateVersion.id
        template.versions = [templateVersion]
        templateVersion.exercises = versions.enumerated().map { index, version in
            let item = TemplateExerciseRecord(id: id(5_310 + index), templateVersionID: templateVersion.id, exerciseVersionID: version.id, sortOrder: index)
            item.plannedDurationMinutes = 10
            item.templateVersion = templateVersion
            item.exerciseVersion = version
            context.insert(item)
            return item
        }
        context.insert(template)
        context.insert(templateVersion)
        return (templateVersion, versions)
    }

    private static func seedPackages(
        clients: [ClientRecord],
        dogs: [DogRecord],
        now: Date,
        context: ModelContext
    ) -> [TrainingPackageRecord] {
        let templates = [
            packageTemplate(id: id(6_001), name: "Trial session", units: 1, price: 0, createdAt: date(months: -12, from: now)),
            packageTemplate(id: id(6_002), name: "5-session package", units: 5, price: 95, createdAt: date(months: -12, from: now)),
            packageTemplate(id: id(6_003), name: "10-session package", units: 10, price: 175, createdAt: date(months: -12, from: now)),
            packageTemplate(id: id(6_004), name: "Private coaching", units: 5, price: 260, createdAt: date(months: -12, from: now))
        ]
        templates.forEach(context.insert)

        let sales: [(Int, Int, Int, Decimal, Int)] = [
            (0, 1, -2, 95, 5), (1, 2, -9, 175, 10), (2, 3, -12, 260, 5),
            (0, 2, -45, 175, 10), (1, 1, -75, 95, 5), (2, 2, -120, 175, 10),
            (0, 3, -180, 260, 5), (1, 0, -1, 0, 1)
        ]
        var packages: [TrainingPackageRecord] = []
        for (index, sale) in sales.enumerated() {
            let client = clients[sale.0]
            let dog = dogs[index % dogs.count]
            let template = templates[sale.1]
            let purchasedAt = date(days: sale.2, from: now)
            let package = TrainingPackageRecord(id: id(6_100 + index), dogID: dog.id, name: template.name, initialUnits: Decimal(sale.4), purchasedAt: purchasedAt)
            package.clientID = client.id
            package.client = client
            package.dog = dog
            package.packageTemplateID = template.id
            package.packageTemplate = template
            package.paymentStatusRawValue = "paid"
            package.priceSnapshot = sale.3
            package.currencyCode = "EUR"
            package.expiresAt = date(years: 1, from: purchasedAt)
            let purchase = PackageLedgerEntryRecord(id: id(6_200 + index), packageID: package.id, kindRawValue: "purchase", unitDelta: 0, createdAt: purchasedAt)
            purchase.moneyDelta = sale.3
            purchase.currencyCode = "EUR"
            purchase.package = package
            package.ledgerEntries = [purchase]
            client.packages = (client.packages ?? []) + [package]
            dog.packages = (dog.packages ?? []) + [package]
            template.packages = (template.packages ?? []) + [package]
            context.insert(package)
            context.insert(purchase)
            packages.append(package)
        }

        for (index, package) in packages.prefix(4).enumerated() {
            let redemption = PackageLedgerEntryRecord(id: id(6_300 + index), packageID: package.id, kindRawValue: "redeem", unitDelta: -Decimal(index + 1), createdAt: date(days: -(index + 1), from: now))
            redemption.reason = "Sample completed training"
            redemption.package = package
            package.ledgerEntries = (package.ledgerEntries ?? []) + [redemption]
            context.insert(redemption)
        }
        return packages
    }

    private static func seedSessions(
        dogs: [DogRecord],
        packages: [TrainingPackageRecord],
        catalog: (template: TemplateVersionRecord, versions: [ExerciseVersionRecord]),
        now: Date,
        context: ModelContext
    ) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: now)
        let definitions: [(String, Date, String, [Int], [String])] = [
            ("Everyday foundations", calendar.date(byAdding: .hour, value: 10, to: startOfDay) ?? now, "scheduled", [0, 1, 2], ["group", "foundation"]),
            ("Recall practice", date(days: 2, from: startOfDay), "scheduled", [1, 3], ["recall", "outdoor"]),
            ("Adolescent group", date(days: -1, from: startOfDay), "completed", [0, 2], ["group", "adolescent"]),
            ("Private coaching", date(days: -4, from: startOfDay), "completed", [3], ["individual", "evaluated"]),
            ("Weekend workshop", date(days: 6, from: startOfDay), "draft", [0, 1, 2, 3], ["workshop"])
        ]

        for (sessionIndex, definition) in definitions.enumerated() {
            let session = ScheduledSessionRecord(id: id(7_001 + sessionIndex), title: definition.0, startAt: definition.1, durationMinutes: sessionIndex == 4 ? 90 : 45)
            session.statusRawValue = definition.2
            session.kindRawValue = definition.3.count == 1 ? "individual" : "group"
            session.locationText = sessionIndex == 1 ? "Riverside park" : "Training hall"
            session.labels = definition.4
            session.templateVersionID = catalog.template.id
            session.templateVersion = catalog.template
            session.packageUnitsPerAttendee = sessionIndex == 4 ? 0 : 1
            session.bookings = definition.3.enumerated().map { bookingIndex, dogIndex in
                let dog = dogs[dogIndex]
                let booking = BookingRecord(id: id(7_100 + sessionIndex * 10 + bookingIndex), sessionID: session.id, dogID: dog.id)
                booking.session = session
                booking.dog = dog
                booking.expectedPackage = packages.first { $0.dogID == dog.id && !$0.isClosed }
                booking.expectedPackageID = booking.expectedPackage?.id
                dog.bookings = (dog.bookings ?? []) + [booking]
                context.insert(booking)
                return booking
            }
            context.insert(session)

            if sessionIndex == 3 {
                seedCompletedSession(session, versions: catalog.versions, context: context)
            }
        }
    }

    private static func seedCompletedSession(_ session: ScheduledSessionRecord, versions: [ExerciseVersionRecord], context: ModelContext) {
        let completion = CompletedSessionRecord(id: id(8_001), sessionID: session.id, completedAt: session.startAt.addingTimeInterval(45 * 60), completionToken: id(8_002))
        completion.requestFingerprint = "debug-demo-completion"
        completion.generalNotes = "SAMPLE DATA — calm progress in a familiar environment"
        completion.session = session
        session.completedSession = completion
        let snapshots = versions.enumerated().map { index, version in
            let localization = version.localizations?.first
            let snapshot = ExerciseSnapshotRecord(id: id(8_100 + index), completedSessionID: completion.id, sourceExerciseID: version.exerciseID, sourceExerciseVersionID: version.id)
            snapshot.title = localization?.title ?? "Exercise"
            snapshot.goal = localization?.goal ?? ""
            snapshot.steps = localization?.steps ?? []
            snapshot.successCriteria = localization?.successCriteria ?? []
            snapshot.completedSession = completion
            context.insert(snapshot)
            return snapshot
        }
        completion.exerciseSnapshots = snapshots
        context.insert(completion)

        for (bookingIndex, booking) in (session.bookings ?? []).enumerated() {
            let attendance = AttendanceRecord(id: id(8_200 + bookingIndex), bookingID: booking.id, statusRawValue: "attended", checkedAt: session.startAt)
            attendance.booking = booking
            booking.attendance = attendance
            attendance.results = snapshots.enumerated().map { exerciseIndex, snapshot in
                let result = DogExerciseResultRecord(id: id(8_300 + bookingIndex * 10 + exerciseIndex), attendanceID: attendance.id, exerciseSnapshotID: snapshot.id)
                result.outcomeRawValue = exerciseIndex == 1 ? "lightSupport" : "independent"
                result.clientFacingNote = exerciseIndex == 1 ? "Keep sessions short and reward the first loose step." : nil
                result.attendance = attendance
                result.exerciseSnapshot = snapshot
                context.insert(result)
                return result
            }
            context.insert(attendance)
            if let dog = booking.dog {
                let report = ClientReportRecord(id: id(8_400 + bookingIndex), dogID: dog.id, completedSessionID: completion.id, localeIdentifier: "en")
                report.body = "Sample report for \(dog.name): steady progress across the planned exercises."
                report.dog = dog
                report.completedSession = completion
                dog.reports = (dog.reports ?? []) + [report]
                completion.reports = (completion.reports ?? []) + [report]
                context.insert(report)
            }
        }
    }

    private static func makeClient(id: UUID, name: String, email: String, phone: String, city: String, country: String, createdAt: Date) -> ClientRecord {
        let client = ClientRecord(id: id, displayName: name, createdAt: createdAt)
        client.email = email
        client.phone = phone
        client.addressCity = city
        client.addressCountryCode = country
        return client
    }

    private static func makeDog(id: UUID, name: String, breed: String, sex: String, birthDate: Date) -> DogRecord {
        let dog = DogRecord(id: id, name: name, createdAt: birthDate)
        dog.birthDate = birthDate
        dog.breedText = breed
        dog.sexRawValue = sex
        return dog
    }

    private static func link(_ client: ClientRecord, to dog: DogRecord, roleID: UUID, context: ModelContext) {
        if (dog.clientRoles ?? []).contains(where: { $0.clientID == client.id }) { return }
        let role = ClientDogRoleRecord(id: roleID, clientID: client.id, dogID: dog.id, isPrimaryContact: true)
        role.client = client
        role.dog = dog
        client.dogRoles = (client.dogRoles ?? []) + [role]
        dog.clientRoles = (dog.clientRoles ?? []) + [role]
        context.insert(role)
    }

    private static func goal(id: UUID, dog: DogRecord, title: String, status: String, target: String, now: Date) -> TrainingGoalRecord {
        let goal = TrainingGoalRecord(id: id, dogID: dog.id, title: title, startedAt: date(months: -2, from: now))
        goal.statusRawValue = status
        goal.targetDescription = target
        goal.completedAt = status == "achieved" ? date(days: -12, from: now) : nil
        goal.dog = dog
        return goal
    }

    private static func packageTemplate(id: UUID, name: String, units: Decimal, price: Decimal, createdAt: Date) -> PackageTemplateRecord {
        PackageTemplateRecord(id: id, name: name, units: units, price: price, currencyCode: "EUR", createdAt: createdAt)
    }

    private static func date(days: Int = 0, months: Int = 0, years: Int = 0, from date: Date) -> Date {
        Calendar.current.date(byAdding: DateComponents(year: years, month: months, day: days), to: date) ?? date
    }

    private static func id(_ suffix: Int) -> UUID {
        UUID(uuidString: String(format: "D09C0000-0000-0000-0000-%012d", suffix))!
    }
}
