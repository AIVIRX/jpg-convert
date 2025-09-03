//
//  StoreView.swift
//  CryptoProfitCalculator
//
//  Created by Maicol Cabreja on 9/21/24.
//

import SwiftUI

struct StoreView: View {
    @EnvironmentObject private var store: Store
    var body: some View {
        VStack{
            List(store.allRecipes, id: \.self) { recipe in
                Group{
                    if !recipe.isLocked {
                        RecipeRow(recipe: recipe){ }
                    } else {
                        RecipeRow(recipe: recipe){
                            if let product = store.product(for: recipe.id){
                                store.purchaseProduct(product)
                            }
                        }
                    }
                }
                .navigationBarItems(trailing: Button("Restore"){
                    store.retorePurchases()
                })
                .onAppear{
                    store.loadStoredPurchases()                }
            }
        }
        .navigationTitle("Shop")
    }
}
