//
//  AppStore.swift
//  jpg converter
//
//  Created by Maicol Cabreja on 11/11/23.
//

import Foundation
import RevenueCat

@MainActor
final class Store: NSObject, ObservableObject {
    @Published var completedPurchases = [String]() {
        didSet {
            saveCompletedPurchases()
        }
    }
    @Published private(set) var customerInfo: CustomerInfo?
    @Published var storeError: String?

    private let removeAdsProductID = "com.JPGConvert.Pro"
    private let removeAdsEntitlementID = "Premium"
    private let userDefaultsKey = "completedPurchases"

    var isPremium: Bool {
        completedPurchases.contains(removeAdsProductID)
    }

    override init() {
        super.init()
        loadStoredPurchases()
        Purchases.shared.delegate = self
        Task { await refreshEntitlements() }
    }

    func loadStoredPurchases() {
        if let storedPurchases = UserDefaults.standard.object(forKey: userDefaultsKey) as? [String] {
            completedPurchases = storedPurchases
        }
        Task { await refreshEntitlements() }
    }

    func restorePurchases() {
        Task {
            do {
                let customerInfo = try await Purchases.shared.restorePurchases()
                applyEntitlements(from: customerInfo)
            } catch {
                storeError = error.localizedDescription
            }
        }
    }

    func refreshStoreData() async {
        await refreshEntitlements()
    }

    func refreshEntitlements() async {
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            applyEntitlements(from: customerInfo)
        } catch {
            storeError = error.localizedDescription
        }
    }

    private func applyEntitlements(from customerInfo: CustomerInfo) {
        self.customerInfo = customerInfo

        let hasRemoveAds = customerInfo.entitlements.all[removeAdsEntitlementID]?.isActive == true
        let updatedPurchases = hasRemoveAds ? [removeAdsProductID] : []

        if updatedPurchases != completedPurchases {
            completedPurchases = updatedPurchases
        }
    }

    private func saveCompletedPurchases() {
        UserDefaults.standard.setValue(completedPurchases, forKey: userDefaultsKey)
    }
}

extension Store: PurchasesDelegate {
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            self.applyEntitlements(from: customerInfo)
        }
    }
}
