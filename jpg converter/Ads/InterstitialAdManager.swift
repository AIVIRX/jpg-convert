//
//  InterstitialAdManager.swift
//  jpg converter
//
//  Created by AI on 2024-06-10.
//

import GoogleMobileAds
import SwiftUI

class InterstitialAdManager: NSObject, ObservableObject, FullScreenContentDelegate {
    private var interstitial: InterstitialAd?
    @Published var isAdReady = false

    func loadInterstitial() {
        InterstitialAd.load(with: AdUnitID.interstitial, request: Request()) { [weak self] ad, error in
            if error != nil {
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
            completion?()
            return
        }
        interstitial.present(from: rootViewController)
        self.isAdReady = false
        completion?()
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        loadInterstitial()
        isAdReady = false
    }
}
