import Foundation
import SwiftData

@MainActor
protocol PersistenceProviding {
    var container: ModelContainer { get }
    var mainContext: ModelContext { get }
}

@MainActor
struct PersistenceProvider: PersistenceProviding {
    let container: ModelContainer

    var mainContext: ModelContext { container.mainContext }
}

