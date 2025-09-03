//
//  RecipeRow.swift
//  CryptoProfitCalculator
//
//  Created by Maicol Cabreja on 9/21/24.
//

import SwiftUI

struct RecipeRow: View {
    var recipe: Recipe
    let action: () -> Void
    var body: some View {
        HStack{
            HStack(alignment: .center){
                ZStack{
                    Image(recipe.imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .cornerRadius(9)
                        .opacity(recipe.isLocked ? 0.8 : 1)
                        .blur(radius: recipe.isLocked ? 3.0 : 0)
                        .padding()
                    Image(systemName: "lock.fill")
                        .font(.largeTitle)
                        .opacity(recipe.isLocked ? 1 : 0)
                }
                Spacer()
                VStack(alignment: .center){
                    Text(recipe.title)
                        .font(.title)
                        .bold()
                    Text(recipe.description)
                        .font(.caption)
                }
                Spacer()
                if let price = recipe.price, recipe.isLocked{
                    Button(action: action, label: {
                        Text(price)
                            .foregroundColor(.white)
                            .padding([.leading, .trailing])
                            .padding([.top, .bottom], 5)
                            .background(Color.black)
                            .cornerRadius(25)
                    })
                }
            }
        }
    }
}
