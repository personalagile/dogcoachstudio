import StoreKit
import SwiftUI

struct PaywallView: View {
    @State private var store = StoreManager()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Label("Work faster with DogCoach Pro", systemImage: "sparkles")
                        .font(.largeTitle.bold())
                    Text("Keep creating sessions, reports, and package records after your trial. Your existing data always remains readable and exportable.")
                        .foregroundStyle(.secondary)

                    if store.state == .loading {
                        ProgressView("Loading prices…")
                    } else if store.products.isEmpty {
                        ContentUnavailableView {
                            Label("Prices currently unavailable", systemImage: "wifi.exclamationmark")
                        } description: {
                            Text("The App Store did not return any products. Check your connection and try again. Your existing data remains available.")
                        } actions: {
                            Button("Try again") { Task { await store.start() } }
                                .buttonStyle(.borderedProminent)
                                .accessibilityIdentifier("retryProductLoadingButton")
                        }
                    } else {
                        ForEach(store.products, id: \.id) { product in
                            productCard(product)
                        }
                    }

                    Button("Restore purchases") { Task { await store.restore() } }
                        .accessibilityIdentifier("restorePurchasesButton")

                    Label("Cancel anytime in your App Store subscription settings.", systemImage: "checkmark.shield")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("Purchases are associated with your Apple ID. DogCoach Studio does not require a separate account or server for core access.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("Upgrade")
            .accessibilityIdentifier("paywallRoot")
            .task { await store.start() }
        }
    }

    private func productCard(_ product: Product) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(product.displayName).font(.headline)
            Text(product.description).foregroundStyle(.secondary)
            Button("Continue — \(product.displayPrice)") { Task { await store.purchase(product) } }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Purchase \(product.displayName), \(product.displayPrice)")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 16))
    }
}
