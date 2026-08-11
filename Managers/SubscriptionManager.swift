import StoreKit
import Foundation

@MainActor
class SubscriptionManager: ObservableObject {
    
    @Published var isPremium: Bool = false
    @Published var currentProductID: String?
    @Published var errorMessage: String?
    
    private let premiumProductID = "com.vithastudios.premium_lifetime"
    private let keychainPremiumKey = "premium.entitled"
    private var hasVerified = false
    
    var onPremiumStateChanged: ((Bool) -> Void)?
    
    // Devuelve el premium persistido en Keychain (sin bloquear). Solo es un cache
    // para arrancar rapido; la autoridad real es StoreKit (entitled).
    var persistedPremium: Bool {
        KeychainStore.shared.string(forKey: keychainPremiumKey) == "1"
    }
    
    func verifyStatus() async {
        // Restaurar desde Keychain de forma inmediata si ya estaba comprado.
        let cached = persistedPremium
        if cached != isPremium {
            isPremium = cached
            onPremiumStateChanged?(cached)
        }
        
        guard !hasVerified else { return }
        hasVerified = true
        
        // Escuchar transacciones en curso (p.ej. en segundo plano).
        Task { [weak self] in
            for await result in Transaction.updates {
                self?.handleTransaction(result)
            }
        }
        
        // Autoridad real: recorrer los entitlements verificados por StoreKit.
        var entitled = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.productID == premiumProductID {
                    entitled = true
                }
                await transaction.finish()
            }
        }
        
        if !entitled && persistedPremium {
            // El cache en Keychain ya no coincide con StoreKit: limpiarlo.
            KeychainStore.shared.remove(forKey: keychainPremiumKey)
        }
        setPremium(entitled, productID: entitled ? premiumProductID : nil)
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
            // Re-verificar entitlements tras restaurar.
            hasVerified = false
            await verifyStatus()
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
                setPremium(true, productID: premiumProductID)
            }
            Task {
                await transaction.finish()
            }
        case .failed:
            // Un fallo de verificacion no debe desactivar premium.
            break
        }
    }
    
    private func setPremium(_ enabled: Bool, productID: String?) {
        let hadChange = isPremium != enabled
        isPremium = enabled
        currentProductID = productID
        
        if enabled {
            KeychainStore.shared.set("1", forKey: keychainPremiumKey)
        } else {
            KeychainStore.shared.remove(forKey: keychainPremiumKey)
        }
        
        if hadChange {
            onPremiumStateChanged?(enabled)
        }
    }
}
