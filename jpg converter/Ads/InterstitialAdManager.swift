//
//  InterstitialAdManager.swift
//  CryptoProfitCalculator
//
//  Created by AI on 2024-06-10.
//

import GoogleMobileAds
import SwiftUI

class InterstitialAdManager: NSObject, ObservableObject, FullScreenContentDelegate {
    private var interstitial: InterstitialAd?
    @Published var isAdReady: Bool = false
    private let adUnitID = "ca-app-pub-2043555402127024/3417484647" // TODO: Replace with your real interstitial ad unit ID

    func loadInterstitial() {
        InterstitialAd.load(with: adUnitID, request: Request()) { [weak self] ad, error in
            if let error = error {
                print("Failed to load interstitial ad: \(error.localizedDescription)")
                self?.isAdReady = false
                return
            }
            self?.interstitial = ad
            self?.interstitial?.fullScreenContentDelegate = self
            self?.isAdReady = true
        }
    }

    func showInterstitial(from rootViewController: UIViewController, completion: (() -> Void)? = nil) {
        guard let interstitial = interstitial else {
            print("Interstitial ad wasn't ready")
            completion?()
            return
        }
        interstitial.present(from: rootViewController)
        self.isAdReady = false
        completion?()
    }

    // Delegate method to reset ad availability after it’s shown
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        self.loadInterstitial()
        self.isAdReady = false
    }
}
