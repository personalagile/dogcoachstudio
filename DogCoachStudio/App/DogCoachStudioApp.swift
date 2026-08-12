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
                    AppRootView(environment: environment)
                        .modelContainer(environment.persistence.container)
                        .task {
                            await environment.diagnostics.record(category: .app, code: .appLaunched)
                        }
    }
}

private struct AppRootView: View {
    let environment: AppEnvironment
    @Environment(\.appLockEnabledBinding) private var appLockEnabled

    var body: some View {
        if ProcessInfo.processInfo.arguments.contains("--phase0-demo") {
            SessionCompletionView()
        } else if ProcessInfo.processInfo.arguments.contains("--phase3-uitesting") {
            CatalogRootView(environment: environment)
        } else if ProcessInfo.processInfo.arguments.contains("--phase4-uitesting") {
            SessionsRootView(environment: environment, seedDemo: true)
        } else if ProcessInfo.processInfo.arguments.contains("--phase5-uitesting") {
            PackagesRootView(environment: environment, seedDemo: true)
        } else if ProcessInfo.processInfo.arguments.contains("--phase6-uitesting") {
            DataControlRootView(environment: environment, appLockEnabled: appLockEnabled)
        } else {
            TabView {
                Tab("People", systemImage: "person.2") { PeopleRootView(environment: environment) }
                Tab("Catalog", systemImage: "books.vertical") { CatalogRootView(environment: environment) }
                Tab("Sessions", systemImage: "calendar") { SessionsRootView(environment: environment) }
                Tab("Packages", systemImage: "ticket") { PackagesRootView(environment: environment) }
                Tab("Data", systemImage: "lock.doc") { DataControlRootView(environment: environment, appLockEnabled: appLockEnabled) }
                Tab("Completion demo", systemImage: "checkmark.circle") { SessionCompletionView() }
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
