//
//  PublicProfileView.swift
//  CampusCloset
//
//  Created by Jun Kuang on 4/20/26.
//
import SwiftUI

struct PublicProfileView: View {
    let sellerName: String
    let sellerId: UUID
    @EnvironmentObject var listingsVM: ListingsViewModel
    
    // Filters listings to show only those belonging to this specific seller
    var sellerListings: [Listing] {
        listingsVM.listings.filter { $0.userId == sellerId }
    }
    
    let columns = [GridItem(.flexible(), spacing: 15), GridItem(.flexible(), spacing: 15)]

    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                
                // MARK: - Header Section (Exact Mirror of ProfileView)
                VStack(spacing: 5) {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .frame(width: 90, height: 90)
                        .foregroundColor(.gray)
                    
                    Text(sellerName)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    // Displaying a static "Member" status or you could pass join date if available
                    Text("CampusCloset Member")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                }
                .padding(.top)
                
                // MARK: - Stats Row (Exact Mirror)
                HStack(spacing: 60) {
                    VStack {
                        Text("\(sellerListings.count)")
                            .font(.title3)
                            .fontWeight(.bold)
                        Text("Listings")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack {
                        Text("0") // Placeholder for Sold items
                            .font(.title3)
                            .fontWeight(.bold)
                        Text("Sold")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 15)
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .cornerRadius(15)
                .padding(.horizontal)
                
                Divider().padding(.horizontal)
                
                // MARK: - Post Gallery (Exact Mirror)
                VStack(alignment: .leading) {
                    Text("Active Posts")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    if sellerListings.isEmpty {
                        ContentUnavailableView("No listings yet", systemImage: "tag.slash")
                            .padding(.top, 30)
                    } else {
                        LazyVGrid(columns: columns, spacing: 15) {
                            ForEach(sellerListings) { listing in
                                NavigationLink(destination: ListingDetailView(listing: listing)) {
                                    VStack(alignment: .leading) {
                                        if let urlString = listing.displayImageUrl, let url = URL(string: urlString) {
                                            AsyncImage(url: url) { phase in
                                                switch phase {
                                                case .success(let image):
                                                    image
                                                        .resizable()
                                                        .scaledToFill()
                                                        .frame(height: 120)
                                                        .clipped()
                                                        .cornerRadius(10)
                                                case .failure, .empty:
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .fill(Color.gray.opacity(0.2))
                                                        .frame(height: 120)
                                                        .overlay(Image(systemName: "photo").foregroundColor(.gray))
                                                @unknown default:
                                                    EmptyView()
                                                }
                                            }
                                        } else {
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(Color.gray.opacity(0.2))
                                                .frame(height: 120)
                                                .overlay(Image(systemName: "photo").foregroundColor(.gray))
                                        }
                                        
                                        Text(listing.title)
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .lineLimit(1)
                                            .foregroundColor(.primary)
                                        
                                        Text(listing.price)
                                            .font(.caption2)
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.bottom, 30)
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
    }
}
