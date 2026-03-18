//
//  ListingDetailView.swift
//  CampusCloset
//
//  Created by Jun Kuang on 3/14/26.
//

import SwiftUI

struct ListingDetailView: View {
    
    let listing: Listing
    
    var body: some View {
        
        VStack(alignment: .leading, spacing: 20) {
            
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 220)
                .cornerRadius(12)
            
            Text(listing.title)
                .font(.title)
                .fontWeight(.bold)
            
            Text(listing.price)
                .font(.title2)
                .foregroundColor(.green)
            
            Text(listing.description)
                .font(.body)
            
            Spacer()
            //doesn't actually worked yet
            Button("Message Seller") {
                
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            
        }
        .padding()
        .navigationTitle("Listing")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    ListingDetailView(
        listing: Listing(
                    id: UUID(),
                    title: "Mini Fridge",
                    price: "$40",
                    description: "Used for one year",
                    imageUrl: nil,
                    createdAt: Date(),
                    userId: UUID() //new random UUID
            )
    )
}
