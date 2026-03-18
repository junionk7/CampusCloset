//
//  ListingsViewModel.swift
//  CampusCloset
//
//  Created by Jun Kuang on 3/15/26.
//

import Foundation
import SwiftUI
import Supabase
import Combine

@MainActor
class ListingsViewModel: ObservableObject {
    @Published var listings: [Listing] = []

    // Fetch from Supabase
    func fetchListings() async {
        do {
            let fetchedListings: [Listing] = try await supabase
                .from("listings") // Matches your table name
                .select()
                .execute()
                .value
            self.listings = fetchedListings
        } catch {
            print("Error fetching: \(error)")
        }
    }

    // Post to Supabase
    func addListing(title: String, price: String, description: String) async {
        let newListing = Listing(title: title, price: price, description: description)
        
        do {
            try await supabase
                .from("listings") // Matches your table name
                .insert(newListing)
                .execute()
            
            // Refresh the list so the new item shows up immediately
            await fetchListings()
        } catch {
            print("Error posting: \(error)")
        }
    }
}
