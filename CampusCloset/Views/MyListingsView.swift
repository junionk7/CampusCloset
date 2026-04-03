//
//  MyListingsView.swift
//  CampusCloset
//
//  Created by Jun Kuang on 4/3/26.
//

import Foundation
import SwiftUI
import Auth

struct MyListingsView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var listingsVM: ListingsViewModel
    
    // Computed property to get only the current user's active listings
    var userListings: [Listing] {
        listingsVM.listings.filter { $0.userId == authVM.currentUser?.id }
    }

    var body: some View {
        List {
            if userListings.isEmpty {
                Text("You haven't posted anything yet.")
                    .foregroundColor(.gray)
                    .padding()
            } else {
                ForEach(userListings) { listing in
                    NavigationLink(destination: ListingDetailView(listing: listing)) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(listing.title)
                                    .font(.headline)
                                Text(listing.price)
                                    .font(.subheadline)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("My Listings")
    }
}
