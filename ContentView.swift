import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @StateObject private var viewModel = PrompterViewModel()
    
    var body: some View {
        ZStack {
            ViewControllerRepresentable(viewModel: viewModel)
                .ignoresSafeArea()            
            if !subscriptionManager.isPremium {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("Prompter AI Free")
                            .font(.caption)
                            .padding(8)
                            .background(Color.black.opacity(0.6))
                            .foregroundColor(.white)
                            .cornerRadius(4)
                            .padding()
                    }
                }
            }
        }
        .sheet(isPresented: $viewModel.showScriptLibrary) {
            ScriptLibraryView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showVideoLibrary) {
            VideoLibraryView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showSettings) {
            SettingsView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showPaywall) {
            PaywallView().environmentObject(subscriptionManager)
        }
        .alert("Atencion", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .alert("Permiso requerido", isPresented: Binding(
            get: { viewModel.permissionDenied != nil },
            set: { if !$0 { viewModel.permissionDenied = nil } }
        )) {
            Button("Cancelar", role: .cancel) { viewModel.permissionDenied = nil }
            Button("Abrir Ajustes") {
                viewModel.permissionDenied = nil
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text(permissionDeniedMessage)
        }
        .overlay {
            if let message = viewModel.statusMessage {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                        Text(message).foregroundColor(.white).font(.subheadline)
                    }
                    .padding()
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(10)
                    .padding(.bottom, 140)
                }
                .transition(.opacity)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        withAnimation { viewModel.statusMessage = nil }
                    }
                }
            }
        }
        .onAppear {
            viewModel.setPremium(subscriptionManager.isPremium)
        }
        .onChange(of: subscriptionManager.isPremium) { _, isPremium in
            viewModel.setPremium(isPremium)
        }
    }
    
    private var permissionDeniedMessage: String {
        switch viewModel.permissionDenied {
        case .camera:
            return "Prompter AI necesita acceso a la camara para grabar tu lectura. Puedes habilitarlo en Ajustes > Privacidad > Camara."
        case .microphone:
            return "Prompter AI necesita acceso al microfono para capturar el audio. Puedes habilitarlo en Ajustes > Privacidad > Microfono."
        case nil:
            return ""
        }
    }
}

struct ViewControllerRepresentable: UIViewControllerRepresentable {
    let viewModel: PrompterViewModel
    
    func makeUIViewController(context: Context) -> ViewController {
        return ViewController(viewModel: viewModel)
    }
    
    func updateUIViewController(_ uiViewController: ViewController, context: Context) {}
}
