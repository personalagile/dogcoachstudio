import Observation
import StoreKit

@MainActor @Observable
final class StoreManager {
    private(set) var products: [Product] = []
    private(set) var entitlements = EntitlementSnapshot()
    private(set) var state: PurchaseState = .idle
    private nonisolated var listener: Task<Void, Never>?

    init(startListener: Bool = true) {
        if startListener { listener = listenForTransactions() }
    }

    deinit { listener?.cancel() }

    func start() async {
        state = .loading
        do {
            products = try await Product.products(for: CommerceProductID.allCases.map(\.rawValue))
                .sorted { $0.price < $1.price }
            await refreshEntitlements()
            state = .idle
        } catch { state = .failed }
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
