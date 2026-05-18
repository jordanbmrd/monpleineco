import Foundation
import UIKit
import GoogleMobileAds

@MainActor
final class AppOpenAdManager: NSObject, GADFullScreenContentDelegate {
    static let shared = AppOpenAdManager()

    private static let adUnitID: String = {
        #if DEBUG
        // ID de test officiel Google pour App Open Ad (iOS).
        return "ca-app-pub-3940256099942544/5575463023"
        #else
        return "ca-app-pub-6294092848271246/1121973570"
        #endif
    }()

    private var appOpenAd: GADAppOpenAd?
    private var isLoadingAd = false
    private var isShowingAd = false
    private var hasShownThisLaunch = false

    private override init() {
        super.init()
    }

    func loadAndShowIfNeeded() {
        guard !hasShownThisLaunch, !isShowingAd else { return }
        loadAd()
    }

    private func loadAd() {
        guard !isLoadingAd, appOpenAd == nil else { return }
        isLoadingAd = true

        // npa=1 → annonces non personnalisées (pas de consentement utilisateur requis).
        let request = GADRequest()
        let extras = GADExtras()
        extras.additionalParameters = ["npa": "1"]
        request.register(extras)

        GADAppOpenAd.load(withAdUnitID: Self.adUnitID, request: request) { [weak self] ad, error in
            guard let self else { return }
            Task { @MainActor in
                self.isLoadingAd = false
                if let error {
                    AppLog.ads.error("Failed to load App Open Ad: \(error.localizedDescription, privacy: .public)")
                    return
                }
                ad?.fullScreenContentDelegate = self
                self.appOpenAd = ad
                self.showAdIfAvailable()
            }
        }
    }

    private func showAdIfAvailable() {
        guard let ad = appOpenAd, !isShowingAd, !hasShownThisLaunch else { return }
        guard let root = Self.topViewController() else { return }
        isShowingAd = true
        ad.present(fromRootViewController: root)
    }

    // MARK: - GADFullScreenContentDelegate

    nonisolated func adDidRecordImpression(_ ad: GADFullScreenPresentingAd) {
        Task { @MainActor in
            self.hasShownThisLaunch = true
        }
    }

    nonisolated func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor in
            AppLog.ads.error("App Open Ad failed to present: \(error.localizedDescription, privacy: .public)")
            self.appOpenAd = nil
            self.isShowingAd = false
        }
    }

    nonisolated func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        Task { @MainActor in
            self.appOpenAd = nil
            self.isShowingAd = false
        }
    }

    // MARK: - Helpers

    private static func topViewController(base: UIViewController? = nil) -> UIViewController? {
        let baseVC = base ?? UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })?.rootViewController

        if let nav = baseVC as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = baseVC as? UITabBarController, let selected = tab.selectedViewController {
            return topViewController(base: selected)
        }
        if let presented = baseVC?.presentedViewController {
            return topViewController(base: presented)
        }
        return baseVC
    }
}
