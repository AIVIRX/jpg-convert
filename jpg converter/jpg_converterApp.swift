//
//  jpg_converterApp.swift
//  jpg converter
//
//  Created by Maicol Cabreja on 8/31/25.
//

import SwiftUI
import AppTrackingTransparency
import GoogleMobileAds
import AdSupport
import FirebaseCore
import RevenueCat

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: {
            if #available(iOS 14, *) {
                ATTrackingManager.requestTrackingAuthorization { status in
                    switch status {
                    case .authorized:
                        MobileAds.shared.start(completionHandler: nil)
                    case .denied:
                        MobileAds.shared.start(completionHandler: nil)
                    default:
                        MobileAds.shared.start(completionHandler: nil)
                    }
                }
            } else {
                MobileAds.shared.start(completionHandler: nil)
            }
        })
        
        FirebaseApp.configure()

        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: "appl_IuMwmKGqRoNoMXPZgpmOYjFakFP")
        
        return true
    }
}

@main
struct jpg_converterApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var store = Store()
    @StateObject private var interstitialAdManager = InterstitialAdManager()
    var body: some Scene {
        WindowGroup {
            VStack{
                if store.isPremium {
                    // IAP bought
                } else {
                    if UIDevice.current.userInterfaceIdiom == .phone {
                        AdView(adUnitID: AdUnitID.banner)
                            .frame(width: 320, height: 50)
                            .padding(5)
                    }
                    
                    if UIDevice.current.userInterfaceIdiom == .pad {
                        AdView(adUnitID: AdUnitID.banner)
                            .frame(width: 468, height: 60)
                            .padding(5)
                    }
                }
                
                ContentView()
                    .environmentObject(store)
                    .environmentObject(interstitialAdManager)
            }
            .onAppear {
                interstitialAdManager.loadInterstitial()
            }
        }
    }
}
