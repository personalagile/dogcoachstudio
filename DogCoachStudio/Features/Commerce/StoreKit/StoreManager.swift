import Observation
import StoreKit

@MainActor @Observable
final class StoreManager {
    private enum LoadingError: Error { case noProducts }
    private(set) var products: [Product] = []
    private(set) var entitlements = EntitlementSnapshot()
    private(set) var state: PurchaseState = .idle
    private var loadAttemptID: UUID?
    @ObservationIgnored private var listener: Task<Void, Never>?

    init(startListener: Bool = true) {
        if startListener { listener = listenForTransactions() }
    }

    func start() async {
        let attemptID = UUID()
        loadAttemptID = attemptID
        state = .loading
        let timeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(12))
            guard !Task.isCancelled else { return }
            self?.markLoadingTimedOut(attemptID: attemptID)
        }
        defer { timeoutTask.cancel() }

        do {
            let loadedProducts = try await Product.products(for: CommerceProductID.allCases.map(\.rawValue))
                .sorted { $0.price < $1.price }
            guard loadAttemptID == attemptID else { return }
            guard !loadedProducts.isEmpty else { throw LoadingError.noProducts }
            products = loadedProducts
            await refreshEntitlements()
            state = .idle
        } catch {
            guard loadAttemptID == attemptID else { return }
            state = .failed
        }
    }

    private func markLoadingTimedOut(attemptID: UUID) {
        guard loadAttemptID == attemptID, state == .loading else { return }
        state = .failed
    }

    func purchase(_ product: Product) async {
        guard let id = CommerceProductID(rawValue: product.id) else { state = .failed; return }
        state = .purchasing(id)
        do {
            switch try await product.purchase() {
            case .success(let result):
                guard case .verified(let transaction) = result else { state = .failed; return }
                apply(transaction)
                await transaction.finish()
                state = .active
            case .pending:
                entitlements.markPending(productID: product.id)
                state = .pending(id)
            case .userCancelled:
                state = .idle
            @unknown default:
                state = .failed
            }
        } catch { state = .failed }
    }

    func restore() async {
        state = .loading
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            state = .active
        } catch { state = .failed }
    }

    func refreshEntitlements() async {
        var snapshot = EntitlementSnapshot()
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            snapshot.applyVerified(productID: transaction.productID, revoked: transaction.revocationDate != nil)
        }
        entitlements = snapshot
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in Transaction.updates {
                guard !Task.isCancelled else { return }
                guard case .verified(let transaction) = result else { continue }
                self?.apply(transaction)
                await transaction.finish()
            }
        }
    }

    private func apply(_ transaction: Transaction) {
        entitlements.applyVerified(productID: transaction.productID, revoked: transaction.revocationDate != nil)
    }
}
