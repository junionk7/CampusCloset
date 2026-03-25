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
        ScrollView{
            VStack(alignment: .leading, spacing: 20) {

        
                if let urlString = listing.imageUrl, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit() // Shows the whole photo without cropping in detail view
                                .frame(maxWidth: .infinity)
                                .frame(height: 300)
                                .background(Color.black.opacity(0.05))
                                .cornerRadius(12)
                        case .failure:
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .frame(maxWidth: .infinity)
                                .frame(height: 300)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(12)
                        case .empty:
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .frame(height: 300)
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    // Fallback if no URL
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 300)
                        .cornerRadius(12)
                        .overlay(Text("No Image Available").foregroundColor(.gray))
                } 
                
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
