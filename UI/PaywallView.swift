import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var price: String = "$9.99"
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                
                Image(systemName: "text.bubble.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .foregroundColor(.white)
                
                Text("Desbloquea Prompter AI Pro")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Grabacion 4K 60fps, sin marca de agua y control por voz avanzado.")
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                VStack(spacing: 15) {
                    FeatureRow(icon: "camera.fill", text: "Video 4K a 60fps")
                    FeatureRow(icon: "mic.fill", text: "Control por Voz IA")
                    FeatureRow(icon: "icloud.fill", text: "Guiones guardados localmente")
                    FeatureRow(icon: "xmark.circle.fill", text: "Sin Marca de Agua")
                }
                .padding(.top, 20)
                
                Spacer()
                
                Button(action: {
                    Task { await subscriptionManager.purchasePremium() }
                }) {
                    Text("Comprar de por vida - \(price)")
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                
                Button(action: {
                    Task { await subscriptionManager.restorePurchases() }
                }) {
                    Text("Restaurar Compra")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .underline()
                }
                .padding(.bottom, 20)
                
                // Terminos de Uso (EULA) y Politica de Privacidad: obligatorios
                // cuando hay compras integradas (guia de App Review 3.1.1).
                VStack(spacing: 12) {
                    Link("Terminos de Uso (EULA)", destination: termsURL)
                        .font(.caption)
                        .foregroundColor(.gray)
                    Link("Politica de Privacidad", destination: privacyURL)
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("Compra de por vida (no renovable).")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 10)
                
                Button(action: { dismiss() }) {
                    Text("Quiza mas tarde")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.bottom, 10)
            }
        }
        .task {
            price = await subscriptionManager.fetchPrice()
        }
    }
    
    private var termsURL: URL {
        URL(string: "https://www.vithastudios.com/sistemas/PrompterAI/terms")!
    }
    private var privacyURL: URL {
        URL(string: "https://www.vithastudios.com/sistemas/PrompterAI/privacy")
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.green)
                .frame(width: 30)
            Text(text)
                .foregroundColor(.white)
            Spacer()
        }
        .padding(.horizontal)
    }
}
