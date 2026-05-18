import SwiftUI
import GoogleMobileAds

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        GADMobileAds.sharedInstance().start { _ in
            Task { @MainActor in
                // Petit délai pour laisser l'UI se monter.
                try? await Task.sleep(nanoseconds: 400_000_000)
                AppOpenAdManager.shared.loadAndShowIfNeeded()
            }
        }
        return true
    }
}

@main
struct MonPleinEcoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                ContentView()
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .handlesExternalEvents(matching: ["*"])
    }
}
