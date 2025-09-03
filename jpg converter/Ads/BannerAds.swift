//
//  BannerAds.swift
//  CryptoProfitCalculator
//
//  Created by Maicol Cabreja on 11/11/23.
//

import SwiftUI
import GoogleMobileAds

struct AdView: UIViewRepresentable{
    var adUnitID: String
    func makeCoordinator() -> Coordinator {
        return Coordinator()
    }
    
    func makeUIView(context: UIViewRepresentableContext<AdView>) -> BannerView{
        let banner = BannerView(adSize: AdSizeBanner)
        
        banner.adUnitID = adUnitID
        banner.rootViewController = UIApplication.shared.getRootViewController()
        banner.delegate = context.coordinator
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            let request = Request()
            request.scene = windowScene
            banner.load(request)
        }
        return banner
    }
    
    func updateUIView(_ uiView: BannerView, context: UIViewRepresentableContext<AdView>) {
    }
    
    class Coordinator: NSObject, BannerViewDelegate{
        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            print("bannerViewDidReceiveAd")
        }
        
        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            print("bannerView:didFailToReceiveAdWithError: \(error.localizedDescription)")
        }
        
        func bannerViewDidRecordImpression(_ bannerView: BannerView) {
            print("bannerViewDidRecordImpression")
        }
        
        func bannerViewWillPresentScreen(_ bannerView: BannerView) {
            print("bannerViewWillPresentScreen")
        }
        
        func bannerViewWillDismissScreen(_ bannerView: BannerView) {
            print("bannerViewWillDIsmissScreen")
        }
        
        func bannerViewDidDismissScreen(_ bannerView: BannerView) {
            print("bannerViewDidDismissScreen")
        }
    }
}

extension UIApplication{
    func getRootViewController()->UIViewController{
        guard let screen = self.connectedScenes.first as? UIWindowScene else{
            return .init()
        }
        guard let root = screen.windows.first?.rootViewController else{
            return .init()
        }
        
        return root
    }
}

