import SwiftUI

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
}

struct ViewControllerRepresentable: UIViewControllerRepresentable {
    let viewModel: PrompterViewModel
    
    func makeUIViewController(context: Context) -> ViewController {
        return ViewController(viewModel: viewModel)
    }
    
    func updateUIViewController(_ uiViewController: ViewController, context: Context) {}
}
