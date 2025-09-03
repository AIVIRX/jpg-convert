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

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: {
            if #available(iOS 14, *) {
                ATTrackingManager.requestTrackingAuthorization { status in
                    switch status {
                    case .authorized:
                        MobileAds.shared.start(completionHandler: nil)
                        print(ASIdentifierManager.shared().advertisingIdentifier.uuidString)
                    case .denied:
                        MobileAds.shared.start(completionHandler: nil)
                        print(ASIdentifierManager.shared().advertisingIdentifier.uuidString)
                    default:
                        print("DEFAULT TRACKING")
                    }
                }
            } else {
                MobileAds.shared.start(completionHandler: nil)
            }
        })
        
        FirebaseApp.configure()
        
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
                if !store.completedPurchases.isEmpty{
                } else {
                    if UIDevice.current.userInterfaceIdiom == .phone {
                        AdView(adUnitID: AdUnitID.finalAds)
                            .frame(width: 320, height: 50)
                            .padding(5)
                    }
                    
                    if UIDevice.current.userInterfaceIdiom == .pad {
                        AdView(adUnitID: AdUnitID.finalAds)
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
