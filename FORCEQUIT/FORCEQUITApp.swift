import SwiftUI

/// App entry point for the FORCEQUIT macOS experience.
@main
struct FORCEQUITApp: App {
    /// Bridges the SwiftUI app lifecycle to the macOS app delegate.
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
