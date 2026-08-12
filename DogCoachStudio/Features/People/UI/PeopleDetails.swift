import SwiftUI

struct ClientDetailView: View {
    let client: ClientSummary
    let model: PeopleFeatureModel
    let present: (PeopleRootView.Sheet) -> Void

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
                let packages = model.packages(clientID: client.id)
                if packages.isEmpty {
                    Text("No packages").foregroundStyle(.secondary)
                }
                ForEach(packages) { package in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(package.name).font(.headline)
                            Spacer()
                            Text(package.status.displayName).font(.caption).foregroundStyle(package.status.tint)
                        }
                        Text(package.dogName).font(.subheadline).foregroundStyle(.secondary)
                        LabeledContent("Balance", value: NSDecimalNumber(decimal: package.balance).stringValue)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("clientPackageRow")
                }
            }
            if let notes = client.privateNotes, !notes.isEmpty {
                Section("Private trainer notes") { Text(notes) }
            }
        }
        .navigationTitle(client.displayName)
        .toolbar {
            Button("Edit", systemImage: "pencil") { present(.editClient(client)) }
                .accessibilityIdentifier("clientEditButton")
            Button(client.isArchived ? "Restore" : "Archive", systemImage: "archivebox") {
                model.perform({ try model.setClientArchived(id: client.id, archived: !client.isArchived) }, operation: "client.archive")
            }
            .accessibilityIdentifier("clientArchiveButton")
        }
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
                Label("Appointments and completed sessions will appear here.", systemImage: "calendar")
                    .foregroundStyle(.secondary)
                Label("Packages will appear here.", systemImage: "ticket")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(dog.name)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Menu("Add", systemImage: "plus") {
                    Button("Contact role") { present(.addRole(dog)) }
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
            Section("Safety") {
                ForEach(dog.safetyFlagRawValues, id: \.self) { Label($0, systemImage: "exclamationmark.triangle") }
                if let note = dog.safetyPrivateNote, !note.isEmpty { Text(note).font(.callout) }
            }
        }
    }

    private var rolesSection: some View {
        Section("Contacts") {
            if dog.roles.isEmpty { Text("No contact assigned").foregroundStyle(.secondary) }
            ForEach(dog.roles) { role in
                HStack {
                    VStack(alignment: .leading) {
                        Text(role.clientName)
                        Text(role.kind.displayName).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if role.isPrimaryContact { Label("Primary", systemImage: "star.fill").labelStyle(.titleAndIcon) }
                }
                .swipeActions {
                    if !role.isPrimaryContact {
                        Button("Make primary") {
                            model.perform({ try model.setPrimary(roleID: role.id, dogID: dog.id) }, operation: "role.primary")
                        }
                    }
                    Button("Remove", role: .destructive) {
                        model.perform({ try model.removeRole(id: role.id) }, operation: "role.remove")
                    }
                }
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
                VStack(alignment: .leading) { Text(goal.title); Text(goal.status.displayName).font(.caption).foregroundStyle(.secondary) }
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
