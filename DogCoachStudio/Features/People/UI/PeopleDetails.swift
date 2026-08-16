import SwiftUI

struct ClientDetailView: View {
    let client: ClientSummary
    let model: PeopleFeatureModel
    let present: (PeopleRootView.Sheet) -> Void
    @State private var contactExportError: AppError?
    @State private var contactExported = false

    var body: some View {
        List {
            Section("Contact") {
                LabeledContent("Name", value: client.displayName)
                if let email = client.email, !email.isEmpty { LabeledContent("Email", value: email) }
                if let phone = client.phone, !phone.isEmpty { LabeledContent("Phone", value: phone) }
            }
            Section("Dogs") {
                let linkedDogs = model.dogs.filter { dog in dog.roles.contains { $0.clientID == client.id } }
                if linkedDogs.isEmpty { Text("No linked dogs").foregroundStyle(.secondary) }
                ForEach(linkedDogs) { dog in
                    Button {
                        model.selection = .dog(dog.id)
                    } label: {
                        HStack {
                            DogPhotoView(assetID: dog.photoAssetID, size: 36)
                            Text(dog.name)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("clientDogLink")
                }
            }
            Section("Packages") {
                let _ = model.contentRevision
                let packages = model.packages(clientID: client.id)
                if packages.isEmpty {
                    Text("No packages").foregroundStyle(.secondary)
                } else {
                    LabeledContent("Booked packages", value: packages.count.formatted())
                    LabeledContent("Revenue", value: packages.compactMap(\.price).reduce(Decimal.zero, +).formatted(.currency(code: "EUR")))
                }
                ForEach(packages) { package in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(package.name).font(.headline)
                            Spacer()
                            Text(package.status.displayName).font(.caption).foregroundStyle(package.status.tint)
                        }
                        if !package.dogName.isEmpty { Text(package.dogName).font(.subheadline).foregroundStyle(.secondary) }
                        if let templateName = package.packageTemplateName { LabeledContent("Purchased package", value: templateName) }
                        if let price = package.price { Text(price, format: .currency(code: "EUR")) }
                        LabeledContent("Balance", value: NSDecimalNumber(decimal: package.balance).stringValue)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("clientPackageRow")
                }
                Button("Sell package") { present(.package(client)) }.accessibilityIdentifier("clientAddPackageButton")
            }
            if let notes = client.privateNotes, !notes.isEmpty {
                Section("Private trainer notes") { Text(notes) }
            }
        }
        .navigationTitle(client.displayName)
        .toolbar {
            Button("Edit", systemImage: "pencil") { present(.editClient(client)) }
                .accessibilityIdentifier("clientEditButton")
            Button("Save to Contacts", systemImage: "person.crop.circle.badge.checkmark") {
                Task {
                    do { try await AppleContactsExporter.export(client); contactExported = true }
                    catch { contactExportError = AppErrorMapper.map(error, operation: "contacts.export") }
                }
            }
            .accessibilityIdentifier("clientExportContactButton")
            Button(client.isArchived ? "Restore" : "Archive", systemImage: "archivebox") {
                model.perform({ try model.setClientArchived(id: client.id, archived: !client.isArchived) }, operation: "client.archive")
            }
            .accessibilityIdentifier("clientArchiveButton")
        }
        .alert("Saved to Contacts", isPresented: $contactExported) { Button("OK") {} }
        .alert("Could not save contact", isPresented: Binding(get: { contactExportError != nil }, set: { if !$0 { contactExportError = nil } })) {
            Button("OK") {}
        } message: { Text(contactExportError?.userMessage ?? "") }
        .accessibilityIdentifier("clientDetail")
    }
}

struct DogFileView: View {
    let dog: DogSummary
    let model: PeopleFeatureModel
    let present: (PeopleRootView.Sheet) -> Void

    var body: some View {
        List {
            Section("Overview") {
                HStack {
                    Spacer()
                    DogPhotoView(assetID: dog.photoAssetID, size: 132)
                    Spacer()
                }
                LabeledContent("Name", value: dog.name)
                if let owner = dog.primaryOwnerName { LabeledContent("Owner", value: owner) }
                if let breed = dog.breedText, !breed.isEmpty { LabeledContent("Breed", value: breed) }
                if let birthDate = dog.birthDate { LabeledContent("Born", value: birthDate.formatted(date: .abbreviated, time: .omitted)) }
            }
            safetySection
            rolesSection
            intakeSection
            goalsSection
            Section("Training record") {
                let trainings = model.completedTrainings(dogID: dog.id)
                if trainings.isEmpty { Text("No completed trainings").foregroundStyle(.secondary) }
                ForEach(trainings) { training in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(training.title).font(.headline)
                        Text(training.completedAt, format: .dateTime.day().month().year().hour().minute())
                        Text(training.outcome).font(.caption).foregroundStyle(.secondary)
                    }
                    .accessibilityIdentifier("dogCompletedTrainingRow")
                }
            }
        }
        .navigationTitle(dog.name)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Menu("Add", systemImage: "plus") {
                    Button("Intake") { present(.intake(dog)) }
                    Button("Training goal") { present(.goal(dog)) }
                }
                .accessibilityIdentifier("dogAddMenu")
                Button("Edit", systemImage: "pencil") { present(.editDog(dog)) }
                    .accessibilityIdentifier("dogEditButton")
                Button(dog.isArchived ? "Restore" : "Archive", systemImage: "archivebox") {
                    model.perform({ try model.setDogArchived(id: dog.id, archived: !dog.isArchived) }, operation: "dog.archive")
                }
                .accessibilityIdentifier("dogArchiveButton")
            }
        }
        .accessibilityIdentifier("dogFile")
    }

    @ViewBuilder private var safetySection: some View {
        if !dog.safetyFlagRawValues.isEmpty || !(dog.safetyPrivateNote ?? "").isEmpty {
            Section("Safety and handling") {
                ForEach(dog.safetyFlagRawValues, id: \.self) { Label($0, systemImage: "exclamationmark.triangle") }
                if let note = dog.safetyPrivateNote, !note.isEmpty { Text(note).font(.callout) }
            }
        }
    }

    private var rolesSection: some View {
        Section("Owner") {
            let ownerRoles = dog.roles.filter { $0.kind == .owner }
            if ownerRoles.isEmpty {
                Button("Assign owner") { present(.editDog(dog)) }
                    .accessibilityIdentifier("dogAssignOwnerButton")
            }
            ForEach(ownerRoles) { role in
                Button {
                    if let client = model.clients.first(where: { $0.id == role.clientID }) { present(.editClient(client)) }
                } label: { HStack {
                    VStack(alignment: .leading) {
                        Text(role.clientName)
                        Text("Owner").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if role.isPrimaryContact { Label("Primary", systemImage: "star.fill").labelStyle(.titleAndIcon) }
                } }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the client editor")
            }
            if !ownerRoles.isEmpty {
                Button("Change owner") { present(.editDog(dog)) }
                    .accessibilityIdentifier("dogChangeOwnerButton")
            }
        }
    }

    private var intakeSection: some View {
        Section("Intake") {
            let _ = model.contentRevision
            if let latest = model.intakeDrafts(dogID: dog.id).first {
                Text(latest.clientFacing.reason.isEmpty ? "Draft saved" : latest.clientFacing.reason)
                Text("Revision \(latest.revision) · \(latest.occurredAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption).foregroundStyle(.secondary)
                IntakeShareButton(artifact: IntakePDFExporter.pdf(
                    draft: latest,
                    dogName: dog.name,
                    clientName: dog.primaryOwnerName
                ))
            } else { Text("No intake yet").foregroundStyle(.secondary) }
            Button("Open intake") { present(.intake(dog)) }.accessibilityIdentifier("dogIntakeButton")
        }
    }

    private var goalsSection: some View {
        Section("Training goals") {
            let _ = model.contentRevision
            let goals = model.goals(dogID: dog.id)
            if goals.isEmpty { Text("No goals yet").foregroundStyle(.secondary) }
            ForEach(goals) { goal in
                Button { present(.editGoal(dog, goal)) } label: {
                    VStack(alignment: .leading) { Text(goal.title); Text(goal.status.displayName).font(.caption).foregroundStyle(.secondary) }
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button("Next status") {
                        model.perform({ try model.advanceGoal(goal) }, operation: "goal.advance")
                    }.tint(.green)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button("Delete", role: .destructive) {
                        model.perform({ try model.deleteGoal(id: goal.id) }, operation: "goal.delete")
                    }
                }
            }
            Button("Add goal") { present(.goal(dog)) }.accessibilityIdentifier("dogGoalButton")
        }
    }
}

private extension ClientDogRoleKind {
    var displayName: String { rawValue.replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression).capitalized }
}

private extension TrainingGoalStatus {
    var displayName: String { rawValue.capitalized }
}

private extension PackageLifecycleStatus {
    var displayName: String { rawValue.capitalized }
    var tint: Color {
        switch self {
        case .active: .green
        case .exhausted, .expired: .orange
        case .closed: .secondary
        }
    }
}
