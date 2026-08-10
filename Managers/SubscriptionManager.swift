import StoreKit
import Foundation

@MainActor
class SubscriptionManager: ObservableObject {
    
    @Published var isPremium: Bool = false
    @Published var currentProductID: String?
    @Published var errorMessage: String?
    
    private let premiumProductID = "com.vithastudios.premium_lifetime"
    
    init() {
        Task {
            await verifyStatus()
        }
    }
    
    func verifyStatus() async {
        Task {
            for await result in Transaction.updates {
                handleTransaction(result)
            }
        }
        
        for await result in Transaction.currentEntitlements {
            handleTransaction(result)
        }
    }
    
    func purchasePremium() async {
        do {
            let products = try await Product.products(for: [premiumProductID])
            guard let product = products.first else {
                errorMessage = "Producto no encontrado en la tienda."
                return
            }
            
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                handleTransaction(verification)
            case .userCancellation:
                errorMessage = "Compra cancelada por el usuario."
            case .pending:
                errorMessage = "Compra pendiente de aprobacion."
            @unknown default:
                errorMessage = "Error desconocido en la compra."
            }
        } catch {
            errorMessage = "Error al iniciar compra: \(error.localizedDescription)"
        }
    }
    
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            errorMessage = nil
        } catch {
            errorMessage = "Error al restaurar: \(error.localizedDescription)"
        }
    }
    
    func fetchPrice() async -> String {
        do {
            let products = try await Product.products(for: [premiumProductID])
            return products.first?.displayPrice ?? "$9.99"
        } catch {
            return "$9.99"
        }
    }
    
    private func handleTransaction(_ verification: VerificationResult<Transaction>) {
        switch verification {
        case .verified(let transaction):
            if transaction.productID == premiumProductID {
                isPremium = true
                currentProductID = premiumProductID
                print("Usuario Premium activado.")
            }
            Task {
                await transaction.finish()
            }
        case .failed(let error):
            errorMessage = "Recibo invalido: \(error.localizedDescription)"
            isPremium = false
        }
    }
}
