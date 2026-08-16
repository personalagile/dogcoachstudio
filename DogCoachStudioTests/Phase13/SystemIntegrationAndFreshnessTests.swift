import Contacts
import PDFKit
import SwiftData
import Testing
@testable import DogCoachStudio

@Suite("Phase 13 live data and system integration")
struct SystemIntegrationAndFreshnessTests {
    @Test("A dog rename emits a shared revision and sessions can reload the new name") @MainActor
    func dogRenameInvalidatesSessionSnapshots() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let changes = AppDataChanges()
        let environment = AppEnvironment(
            persistence: PersistenceProvider(container: container),
            clock: SystemAppClock(),
            uuidGenerator: SystemUUIDGenerator(),
            dataExporter: UnavailableDataExporter(),
            diagnostics: DiagnosticRecorder(),
            dataChanges: changes
        )
        let dog = DogRecord(name: "Old name")
        container.mainContext.insert(dog)
        try container.mainContext.save()
        let sessions = SessionsFeatureModel(environment: environment)
        let people = PeopleFeatureModel(
            context: container.mainContext,
            clock: environment.clock,
            uuidGenerator: environment.uuidGenerator,
            dataChanges: changes
        )

        try people.editDog(id: dog.id, draft: DogDraft(name: "New name", photoAssetID: nil, birthDate: nil, breedText: nil, sexRawValue: nil, safetyFlagRawValues: [], safetyPrivateNote: nil), ownerClientID: nil)

        #expect(changes.revision == 1)
        sessions.reload()
        #expect(sessions.dogs.first?.name == "New name")
    }

    @Test("Purchased package summary identifies its template") @MainActor
    func purchaseIdentifiesTemplate() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let context = container.mainContext
        let client = ClientRecord(displayName: "Taylor")
        context.insert(client)
        try context.save()
        let repository = PackageLedgerRepository(context: context, uuid: SystemUUIDGenerator(), clock: SystemAppClock())
        let templateID = try repository.createTemplate(.init(name: "Puppy course", unitType: .session, units: 6, price: 120, currencyCode: "EUR"))
        _ = try repository.createPackage(.init(dogID: UUID(), name: "Purchase 2026", unitType: .session, initialUnits: 6, purchasedAt: .now, expiresAt: nil, paymentStatus: .paid, price: 120, currencyCode: "EUR", clientID: client.id, packageTemplateID: templateID))

        let purchase = try #require(try repository.summaries().first)
        #expect(purchase.packageTemplateID == templateID)
        #expect(purchase.packageTemplateName == "Puppy course")
    }

    @Test("Apple contact mapping imports client fields and exports a contact") @MainActor
    func contactMapping() throws {
        let contact = CNMutableContact()
        contact.givenName = "Ada"
        contact.familyName = "Lovelace"
        contact.emailAddresses = [CNLabeledValue(label: CNLabelWork, value: "ada@example.test" as NSString)]
        contact.phoneNumbers = [CNLabeledValue(label: CNLabelPhoneNumberMain, value: CNPhoneNumber(stringValue: "+49 123"))]
        let address = CNMutablePostalAddress()
        address.street = "Main Street 1"; address.postalCode = "12345"; address.city = "Berlin"; address.isoCountryCode = "DE"
        contact.postalAddresses = [CNLabeledValue(label: CNLabelWork, value: address)]

        let imported = try AppleContactsMapper.importedContact(from: contact)
        #expect(imported.displayName.contains("Ada"))
        #expect(imported.email == "ada@example.test")
        #expect(imported.phone == "+49 123")
        #expect(imported.city == "Berlin")

        let client = ClientSummary(id: UUID(), displayName: "Grace Hopper", email: "grace@example.test", phone: "+1 555", addressStreet: "Navy Road", addressPostalCode: "10000", addressCity: "New York", addressCountryCode: "US", privateNotes: nil, isArchived: false)
        let exported = AppleContactsMapper.mutableContact(from: client)
        #expect(exported.givenName == "Grace Hopper")
        #expect(exported.emailAddresses.first.map { String($0.value) } == "grace@example.test")
        #expect(exported.postalAddresses.first?.value.city == "New York")
    }

    @Test("Intake PDF includes client-facing fields and excludes trainer-private notes") @MainActor
    func intakePDFPrivacy() throws {
        let draft = IntakeDraft(
            dogID: UUID(),
            occurredAt: Date(timeIntervalSince1970: 1_800_000_000),
            clientFacing: .init(reason: "CLIENT-REASON", environment: "CLIENT-ENVIRONMENT", desiredOutcome: "CLIENT-GOAL"),
            privateFields: .init(trainerNotes: "PRIVATE-CANARY")
        )
        let artifact = IntakePDFExporter.pdf(draft: draft, dogName: "Milo", clientName: "Alex")
        let document = try #require(PDFDocument(data: artifact.data))
        let text = document.string ?? ""

        #expect(document.pageCount >= 1)
        #expect(text.contains("Milo"))
        #expect(text.contains("CLIENT-REASON"))
        #expect(text.contains("CLIENT-ENVIRONMENT"))
        #expect(text.contains("CLIENT-GOAL"))
        #expect(!text.contains("PRIVATE-CANARY"))
        #expect(artifact.filename == "intake-milo.pdf")
    }
}
