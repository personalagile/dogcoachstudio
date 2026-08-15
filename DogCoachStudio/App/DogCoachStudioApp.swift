import SwiftUI
import SwiftData

@main
struct DogCoachStudioApp: App {
    private let bootstrap: Result<AppEnvironment, AppError>

    init() {
        do {
            bootstrap = .success(try ProcessInfo.processInfo.arguments.contains("--uitesting") ? AppEnvironment.uiTesting() : AppEnvironment.live())
        } catch {
            bootstrap = .failure(AppErrorMapper.map(error, operation: "bootstrap"))
        }
    }

    var body: some Scene {
        WindowGroup {
            switch bootstrap {
            case .success(let environment):
                if Self.shouldWrapInLock {
                    AppLockContainer(enabled: Self.lockEnabled) {
                        ConfiguredAppRoot(environment: environment)
                    }
                } else {
                    ConfiguredAppRoot(environment: environment)
                }
            case .failure(let error):
                StartupFailureView(error: error)
            }
        }
    }

    private static var shouldWrapInLock: Bool {
        !ProcessInfo.processInfo.arguments.contains("--uitesting") || ProcessInfo.processInfo.arguments.contains("--lock-enabled")
    }

    private static var lockEnabled: Bool {
        if ProcessInfo.processInfo.arguments.contains("--uitesting") {
            return ProcessInfo.processInfo.arguments.contains("--lock-enabled")
        }
        return UserDefaults.standard.bool(forKey: "appLockEnabled")
    }
}

private struct ConfiguredAppRoot: View {
    let environment: AppEnvironment

    var body: some View {
        ProductionBootstrapRoot(environment: environment)
            .modelContainer(environment.persistence.container)
            .task {
                await environment.diagnostics.record(category: .app, code: .appLaunched)
            }
            .task(id: environment.dataChanges.revision) {
                try? await LocalNotificationService().reschedule(
                    context: environment.persistence.mainContext,
                    preferences: .stored(),
                    now: environment.clock.now()
                )
            }
    }
}

private struct ProductionBootstrapRoot: View {
    let environment: AppEnvironment
    @Query private var clients: [ClientRecord]
    @AppStorage("productionOnboardingCompleted") private var onboardingCompleted = false
    @State private var completedThisLaunch = false

    private var isUITestOnboarding: Bool {
        ProcessInfo.processInfo.arguments.contains("--phase17-uitesting")
    }

    private var shouldShowOnboarding: Bool {
        !completedThisLaunch && (isUITestOnboarding || (!onboardingCompleted && clients.isEmpty))
    }

    var body: some View {
        if shouldShowOnboarding {
            ProductionOnboardingView { includeSampleData in
                if includeSampleData {
                    try DemoDataSeeder.seedIfNeeded(
                        context: environment.persistence.mainContext,
                        clock: environment.clock,
                        uuidGenerator: environment.uuidGenerator
                    )
                    environment.dataChanges.notify()
                }
                if !isUITestOnboarding {
                    onboardingCompleted = true
                }
                completedThisLaunch = true
            }
        } else {
            AppRootView(environment: environment)
        }
    }
}

private struct ProductionOnboardingView: View {
    let complete: (Bool) throws -> Void
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "pawprint.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            VStack(spacing: 8) {
                Text("Welcome to DogCoach Studio")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                Text("Start with an empty workspace for real client data, or add clearly marked sample records to explore the app.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            VStack(spacing: 12) {
                Button("Start with an empty workspace") { finish(includeSampleData: false) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityIdentifier("onboardingStartEmptyButton")
                Button("Explore with sample data") { finish(includeSampleData: true) }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .accessibilityIdentifier("onboardingLoadSampleButton")
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("onboardingError")
            }
            Spacer()
            Text("Sample data is optional and remains on this device until you delete it.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: 620, maxHeight: .infinity)
        .frame(maxWidth: .infinity)
    }

    private func finish(includeSampleData: Bool) {
        do {
            try complete(includeSampleData)
        } catch {
            errorMessage = String(localized: "The workspace could not be prepared.")
        }
    }
}

private struct AppRootView: View {
    let environment: AppEnvironment
    @Environment(\.appLockEnabledBinding) private var appLockEnabled

    var body: some View {
        if ProcessInfo.processInfo.arguments.contains("--phase3-uitesting") {
            CatalogRootView(environment: environment)
        } else if ProcessInfo.processInfo.arguments.contains("--phase4-uitesting") {
            SessionsRootView(environment: environment, seedDemo: true)
        } else if ProcessInfo.processInfo.arguments.contains("--phase5-uitesting") {
            PackagesRootView(environment: environment, seedDemo: true)
        } else if ProcessInfo.processInfo.arguments.contains("--phase6-uitesting") {
            DataControlRootView(environment: environment, appLockEnabled: appLockEnabled)
        } else if ProcessInfo.processInfo.arguments.contains("--phase7-uitesting") {
            PaywallView()
        } else if ProcessInfo.processInfo.arguments.contains("--phase16-uitesting") {
            FinanceRootView(environment: environment, seedDemo: true)
        } else {
            TabView {
                Tab("People", systemImage: "person.2") { PeopleRootView(environment: environment) }
                Tab("Catalog", systemImage: "books.vertical") { CatalogRootView(environment: environment) }
                Tab("Sessions", systemImage: "calendar") { SessionsRootView(environment: environment) }
                Tab("Packages", systemImage: "ticket") { PackagesRootView(environment: environment) }
                Tab("Finance", systemImage: "chart.bar.xaxis") { FinanceRootView(environment: environment) }
                Tab("Data", systemImage: "lock.doc") { DataControlRootView(environment: environment, appLockEnabled: appLockEnabled) }
                Tab("Upgrade", systemImage: "sparkles") { PaywallView() }
            }
            .accessibilityIdentifier("appRootTabs")
        }
    }
}

private struct StartupFailureView: View {
    let error: AppError

    var body: some View {
        ContentUnavailableView {
            Label("DogCoach Studio could not start", systemImage: "exclamationmark.triangle")
        } description: {
            Text(error.userMessage)
        }
        .accessibilityIdentifier("startupFailure")
    }
}
