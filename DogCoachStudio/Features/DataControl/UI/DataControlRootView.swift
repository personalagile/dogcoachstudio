import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct DataControlRootView: View {
    let environment: AppEnvironment
    @Binding var appLockEnabled: Bool
    @State private var exportStatus: String?
    @State private var isExporting = false
    @State private var backupURL: URL?
    @State private var isChoosingBackup = false
    @State private var pendingRestore: BackupPackage?
    @State private var restoreSummary: DataRestoreSummary?
    @State private var isRestoring = false
    @State private var showRestoreConfirmation = false
    @AppStorage("notifications.sessions") private var sessionReminders = false
    @AppStorage("notifications.birthdays") private var birthdayReminders = false
    @AppStorage("notifications.evaluations") private var evaluationReminders = false
    @State private var notificationStatus: String?
    @State private var diagnosticsURL: URL?

    var body: some View {
        NavigationStack {
            Form {
                Section("Your data") {
                    Button {
                        Task { await createBackup() }
                    } label: {
                        Label("Create JSON and CSV backup", systemImage: "square.and.arrow.up")
                    }
                    .disabled(isExporting)
                    .accessibilityIdentifier("dataExportButton")

                    Button {
                        isChoosingBackup = true
                    } label: {
                        Label("Restore from backup", systemImage: "square.and.arrow.down")
                    }
                    .disabled(isExporting || isRestoring)
                    .accessibilityIdentifier("dataRestoreButton")

                    if let backupURL {
                        ShareLink(item: backupURL) {
                            Label("Share backup", systemImage: "square.and.arrow.up")
                        }
                        .accessibilityIdentifier("dataBackupShareLink")
                    }

                    if let exportStatus {
                        Text(exportStatus)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("dataExportStatus")
                    }

                    Text("Before permanent deletion, DogCoach Studio shows dependent records and recommends an export. Business history can be archived instead.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("deletionPolicySummary")

                    Text("A backup can be restored only into an empty workspace. Records, relationships, dog photos, and exercise media are integrity-checked before import.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Privacy") {
                    Toggle("Require device authentication", isOn: $appLockEnabled)
                        .accessibilityIdentifier("appLockToggle")
                    Text("When enabled, the app locks after leaving the foreground and hides its content in the app switcher. Device passcode is available when biometrics cannot be used.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Notifications") {
                    Toggle("Session reminders", isOn: $sessionReminders)
                        .accessibilityIdentifier("sessionReminderToggle")
                    Toggle("Dog birthday reminders", isOn: $birthdayReminders)
                        .accessibilityIdentifier("birthdayReminderToggle")
                    Toggle("Unevaluated training reminders", isOn: $evaluationReminders)
                        .accessibilityIdentifier("evaluationReminderToggle")
                    if let notificationStatus { Text(notificationStatus).font(.footnote).foregroundStyle(.secondary) }
                }
                .onChange(of: sessionReminders) { updateNotifications() }
                .onChange(of: birthdayReminders) { updateNotifications() }
                .onChange(of: evaluationReminders) { updateNotifications() }

                Section("Pilot support") {
                    Button {
                        Task { await createDiagnostics() }
                    } label: {
                        Label("Create privacy-safe diagnostics", systemImage: "waveform.path.ecg")
                    }
                    .accessibilityIdentifier("diagnosticsExportButton")
                    if let diagnosticsURL {
                        ShareLink(item: diagnosticsURL) {
                            Label("Share diagnostics", systemImage: "square.and.arrow.up")
                        }
                        .accessibilityIdentifier("diagnosticsShareLink")
                    }
                    Text("Diagnostics contain timestamps and typed event codes only—never names, contact details, notes, or report text.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Data & Privacy")
            .accessibilityIdentifier("dataControlRoot")
            .task { await rescheduleNotifications(requestPermission: false) }
            .fileImporter(isPresented: $isChoosingBackup, allowedContentTypes: [.json]) { result in
                Task { await prepareRestore(result) }
            }
            .confirmationDialog("Restore this backup?", isPresented: $showRestoreConfirmation, titleVisibility: .visible) {
                Button("Restore backup") { Task { await restoreBackup() } }
                Button("Cancel", role: .cancel) { pendingRestore = nil; restoreSummary = nil }
            } message: {
                if let restoreSummary {
                    Text("This will import \(restoreSummary.recordCount) records and \(restoreSummary.assetCount) media files. Existing workspaces are never overwritten.")
                }
            }
        }
    }

    @MainActor
    private func prepareRestore(_ result: Result<URL, Error>) async {
        do {
            let url = try result.get()
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            let package = try DataBackupService.decodeAndValidate(Data(contentsOf: url))
            let service = DataBackupRestoreService(context: environment.persistence.mainContext)
            pendingRestore = package
            restoreSummary = service.preview(package)
            showRestoreConfirmation = true
        } catch {
            pendingRestore = nil
            restoreSummary = nil
            exportStatus = String(localized: "The backup is damaged, incompatible, or failed its integrity check.")
        }
    }

    @MainActor
    private func restoreBackup() async {
        guard let pendingRestore else { return }
        isRestoring = true
        defer { isRestoring = false }
        do {
            let summary = try DataBackupRestoreService(context: environment.persistence.mainContext).restore(pendingRestore)
            self.pendingRestore = nil
            restoreSummary = nil
            environment.dataChanges.notify()
            exportStatus = String(localized: "Backup restored: \(summary.recordCount) records and \(summary.assetCount) media files.")
        } catch DataRestoreError.storeNotEmpty {
            exportStatus = String(localized: "Restore stopped because this workspace already contains data. No records were changed.")
        } catch {
            exportStatus = String(localized: "The backup could not be restored. No records were changed.")
        }
    }

    private func updateNotifications() {
        Task { await rescheduleNotifications(requestPermission: sessionReminders || birthdayReminders || evaluationReminders) }
    }

    @MainActor
    private func rescheduleNotifications(requestPermission: Bool) async {
        do {
            let service = LocalNotificationService()
            if requestPermission, !(try await service.requestAuthorization()) {
                sessionReminders = false; birthdayReminders = false; evaluationReminders = false
                notificationStatus = String(localized: "Notifications are disabled in Settings.")
                return
            }
            try await service.reschedule(
                context: environment.persistence.mainContext,
                preferences: .init(sessionReminders: sessionReminders, birthdayReminders: birthdayReminders, evaluationReminders: evaluationReminders),
                now: environment.clock.now()
            )
            notificationStatus = String(localized: "Notification schedule updated.")
        } catch {
            notificationStatus = String(localized: "Notifications could not be scheduled.")
        }
    }

    @MainActor
    private func createBackup() async {
        isExporting = true
        defer { isExporting = false }
        do {
            let service = DataBackupService(context: environment.persistence.mainContext, now: environment.clock.now)
            let data = try service.encodedPackage()
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("dogcoach-backup.json")
            try ProtectedFileWriter().write(data, to: url)
            backupURL = url
            exportStatus = String(localized: "Backup created and integrity checked.")
            await environment.diagnostics.record(category: .export, code: .exportSucceeded)
        } catch {
            exportStatus = String(localized: "Backup could not be created.")
            await environment.diagnostics.record(category: .export, code: .unexpectedFailure)
        }
    }

    private func createDiagnostics() async {
        do {
            let artifact = try await environment.diagnostics.export()
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(artifact.suggestedFilename)
            try ProtectedFileWriter().write(artifact.data, to: url)
            diagnosticsURL = url
            exportStatus = String(localized: "Privacy-safe diagnostics created.")
        } catch {
            exportStatus = String(localized: "Diagnostics could not be created.")
        }
    }
}

struct AppLockContainer<Content: View>: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var model: AppLockModel
    @State private var enabled: Bool
    private let content: Content

    init(enabled: Bool, @ViewBuilder content: () -> Content) {
        _model = State(initialValue: AppLockModel(isEnabled: enabled))
        _enabled = State(initialValue: enabled)
        self.content = content()
    }

    var body: some View {
        Group {
            if enabled && scenePhase != .active {
                PrivacyShieldView()
            } else if model.isLocked {
                LockedView(model: model)
            } else {
            content
                .privacySensitive()
                .environment(\.appLockEnabledBinding, Binding(
                    get: { enabled },
                    set: { value in
                        enabled = value
                        model.isEnabled = value
                        if !ProcessInfo.processInfo.arguments.contains("--uitesting") {
                            UserDefaults.standard.set(value, forKey: "appLockEnabled")
                        }
                        if value { model.movedToBackground() }
                    }
                ))
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { model.movedToBackground() }
        }
    }
}

private struct LockedView: View {
    let model: AppLockModel

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 52))
                .accessibilityHidden(true)
            Text("DogCoach Studio is locked").font(.title2.bold())
            if let error = model.errorMessage { Text(error).multilineTextAlignment(.center).foregroundStyle(.secondary) }
            Button("Unlock") { Task { await model.unlock() } }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("appUnlockButton")
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
        .accessibilityIdentifier("appLockedView")
    }
}

private struct PrivacyShieldView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground)
            Label("DogCoach Studio", systemImage: "lock.shield")
                .font(.title2.bold())
        }
        .ignoresSafeArea()
        .accessibilityIdentifier("privacyShield")
    }
}

private struct AppLockEnabledBindingKey: EnvironmentKey {
    static let defaultValue: Binding<Bool> = .constant(false)
}

extension EnvironmentValues {
    var appLockEnabledBinding: Binding<Bool> {
        get { self[AppLockEnabledBindingKey.self] }
        set { self[AppLockEnabledBindingKey.self] = newValue }
    }
}
