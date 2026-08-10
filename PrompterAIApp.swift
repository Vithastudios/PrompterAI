import SwiftUI

@main
struct PrompterAIApp: App {
    @StateObject private var subscriptionManager = SubscriptionManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(subscriptionManager)
                .onAppear {
                    Task {
                        await subscriptionManager.verifyStatus()
                    }
                }
        }
    }
}
