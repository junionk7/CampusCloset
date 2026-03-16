//
//  SearchView.swift
//  CampusCloset
//
//  Created by Jun Kuang on 3/16/26.
//

import SwiftUI

struct SearchView: View {
    
    @EnvironmentObject var listingsVM: ListingsViewModel
    @State private var searchText = ""
    
    var filteredListings: [Listing] {
        if searchText.isEmpty {
            return listingsVM.listings
        } else {
            return listingsVM.listings.filter {
                $0.title.lowercased().contains(searchText.lowercased())
            }
        }
    }

    var body: some View {
        
        NavigationStack {
            List(filteredListings) { listing in
                VStack(alignment: .leading) {
                    Text(listing.title)
                        .font(.headline)
                    
                    Text(listing.price)
                        .foregroundColor(.green)
                }
            }
            .searchable(text: $searchText)
            .navigationTitle("Search Listings")
        }
    }
}

#Preview {
    SearchView()
        .environmentObject(ListingsViewModel())
}
