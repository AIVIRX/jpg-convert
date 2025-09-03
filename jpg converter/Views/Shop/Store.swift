//
//  Store.swift
//  CryptoProfitCalculator
//
//  Created by Maicol Cabreja on 11/11/23.
//

import StoreKit

typealias FetchCompletionHandler = (([SKProduct])-> Void)
typealias purchaseCompletionHandler = ((SKPaymentTransaction?)->Void)

class Store: NSObject, ObservableObject{
    
    @Published var allRecipes  = [Recipe]()
    
    private let allProductIdentifiers = Set([
        "com.removeads.profitloss"
    ])
    
    var completedPurchases = [String](){
        didSet{
            DispatchQueue.main.async { [weak self] in
                guard let self = self else{return}
                for index in self.allRecipes.indices {
                    self.allRecipes[index].isLocked = !self.completedPurchases.contains(self.allRecipes[index].id)
                }
            }
        }
    }
    
    private var productsRequest: SKProductsRequest?
    private var fetchedProducts = [SKProduct]()
    private var fetchCompletionHandler: FetchCompletionHandler?
    private var purchaseCompletionHandler: purchaseCompletionHandler?
    
    private let userDefaultsKey = "completedPurchases"
    
    override init() {
        super.init()
        loadStoredPurchases()
        startObservingPaymentQueue()
        
        fetchProducts{products in
            self.allRecipes = products.map{ Recipe(product:$0)}
        }
    }
    
    func loadStoredPurchases(){
        if let storedPurchases = UserDefaults.standard.object(forKey: userDefaultsKey) as? [String]{
            self.completedPurchases = storedPurchases
        }
    }
    
    private func startObservingPaymentQueue(){
        SKPaymentQueue.default().add(self)
    }
    
    private func fetchProducts( completion: @escaping FetchCompletionHandler){
        guard self.productsRequest == nil else{return}
        
        fetchCompletionHandler = completion
        
        productsRequest = SKProductsRequest(productIdentifiers: allProductIdentifiers)
        productsRequest?.delegate = self
        productsRequest?.start()
    }
    
    private func buy(_ product: SKProduct, completion: @escaping purchaseCompletionHandler){
        purchaseCompletionHandler = completion
        
        let payment = SKPayment(product: product)
        SKPaymentQueue.default().add(payment)
    }
}

extension Store {
    func product(for identifier: String) -> SKProduct?{
        return fetchedProducts.first(where: {$0.productIdentifier == identifier})
    }
    
    func purchaseProduct(_ product: SKProduct){
        startObservingPaymentQueue()
        buy(product) {_ in }
    }
    
    func retorePurchases(){
        SKPaymentQueue.default().restoreCompletedTransactions()
    }
}


extension Store: SKPaymentTransactionObserver{
    func paymentQueue(_ queue: SKPaymentQueue,
                      shouldAddStorePayment payment: SKPayment,
                      for product: SKProduct) -> Bool {
        true
    }
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            var shouldFinishTransaction = false
            switch transaction.transactionState{
                
            case .purchased, .restored:
                completedPurchases.append(transaction.payment.productIdentifier  )
                shouldFinishTransaction = true
            case .failed:
                shouldFinishTransaction = true
            case .deferred, .purchasing:
                break
            @unknown default:
                break
            }
            if shouldFinishTransaction{
                SKPaymentQueue.default().finishTransaction(transaction)
                DispatchQueue.main.async{
                    self.purchaseCompletionHandler?(transaction)
                    self.purchaseCompletionHandler = nil
                }
            }
        }
        
        if !completedPurchases.isEmpty{
            UserDefaults.standard.setValue(completedPurchases, forKey: userDefaultsKey)
        }
    }
}

extension Store: SKProductsRequestDelegate{
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        let loadedProducts = response.products
        let invalidProducts = response.invalidProductIdentifiers
        
        guard !loadedProducts.isEmpty else{
            print("Could not load the products!")
            if !invalidProducts.isEmpty{
                print("Invalid products found: \(invalidProducts)")
            }
            productsRequest = nil
            return
        }
        
        //fetch the fetched products
        fetchedProducts = loadedProducts
        
        //notify anyone waiting on product load
        DispatchQueue.main.async {
            self.fetchCompletionHandler?(loadedProducts)
            
            self.fetchCompletionHandler = nil
            self.productsRequest = nil
        }
    }
}
