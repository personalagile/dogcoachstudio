import Foundation

struct ClientFacingExerciseResult: Hashable, Sendable {
    let exerciseTitle: String
    let goal: String
    let outcome: ExerciseOutcome
    let clientFacingNote: String?
}

struct ReportCompositionInput: Hashable, Sendable {
    let dogName: String
    let sessionTitle: String
    let sessionDate: Date
    let results: [ClientFacingExerciseResult]
}

struct ComposedReport: Hashable, Sendable {
    let title: String
    let sections: [Section]
    struct Section: Hashable, Sendable { let heading: String; let paragraphs: [String] }
    var plainText: String { ([title] + sections.flatMap { [$0.heading] + $0.paragraphs }).joined(separator: "\n\n") }
}

enum ReportLocale: String, Sendable { case de, en }
enum ReportApprovalError: Error, Equatable, Sendable { case reportNotFound, approvalRequired }

enum ReportComposer {
    static func compose(_ input: ReportCompositionInput, locale: ReportLocale) -> ComposedReport {
        let title = locale == .de ? "Trainingsbericht für \(input.dogName)" : "Training report for \(input.dogName)"
        let summaryHeading = locale == .de ? "Training" : "Session"
        let date = input.sessionDate.formatted(.dateTime.year().month().day().locale(Locale(identifier: locale.rawValue)))
        let summary = "\(input.sessionTitle) · \(date)"
        let resultHeading = locale == .de ? "Übungen" : "Exercises"
        let paragraphs = input.results.map { result in
            let outcome = localizedOutcome(result.outcome, locale: locale)
            return ["\(result.exerciseTitle): \(outcome)", result.goal, result.clientFacingNote].compactMap { $0?.isEmpty == false ? $0 : nil }.joined(separator: " — ")
        }
        return .init(title: title, sections: [.init(heading: summaryHeading, paragraphs: [summary]), .init(heading: resultHeading, paragraphs: paragraphs)])
    }

    private static func localizedOutcome(_ value: ExerciseOutcome, locale: ReportLocale) -> String {
        switch (locale, value) {
        case (.de, .notStarted): "Nicht begonnen"
        case (.de, .strongSupport): "Mit viel Unterstützung"
        case (.de, .lightSupport): "Mit leichter Unterstützung"
        case (.de, .independent): "Selbstständig"
        case (.de, .stableWithDistraction): "Stabil unter Ablenkung"
        case (.en, .notStarted): "Not started"
        case (.en, .strongSupport): "With strong support"
        case (.en, .lightSupport): "With light support"
        case (.en, .independent): "Independent"
        case (.en, .stableWithDistraction): "Stable with distraction"
        }
    }
}
