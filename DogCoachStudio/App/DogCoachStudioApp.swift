import SwiftUI
import SwiftData

@main
struct DogCoachStudioApp: App {
    private let bootstrap: Result<AppEnvironment, AppError>

    init() {
        do {
            bootstrap = .success(try AppEnvironment.live())
        } catch {
            bootstrap = .failure(AppErrorMapper.map(error, operation: "bootstrap"))
        }
    }

    var body: some Scene {
        WindowGroup {
            switch bootstrap {
            case .success(let environment):
                AppRootView(environment: environment)
                    .modelContainer(environment.persistence.container)
                    .task {
                        await environment.diagnostics.record(category: .app, code: .appLaunched)
                    }
            case .failure(let error):
                StartupFailureView(error: error)
            }
        }
    }
}

private struct AppRootView: View {
    let environment: AppEnvironment

    var body: some View {
        if ProcessInfo.processInfo.arguments.contains("--phase0-demo") {
            SessionCompletionView()
        } else {
            TabView {
                Tab("People", systemImage: "person.2") { PeopleRootView(environment: environment) }
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
