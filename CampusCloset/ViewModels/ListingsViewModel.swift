//
//  ListingsViewModel.swift
//  CampusCloset
//
//  Created by Jun Kuang on 3/15/26.
//

import Foundation
import SwiftUI
import Supabase
import Auth
import UIKit
import Combine

// NEW: Sort Options Enum
enum SortOption: String, CaseIterable {
    case mostRecent = "Most Recent"
    case priceLowHigh = "Price (L-H)"
    case priceHighLow = "Price (H-L)"
    case free = "Free"
}

@MainActor
class ListingsViewModel: ObservableObject {
    @Published var listings: [Listing] = []
    
    // MARK: - Filter State
    @Published var selectedCategory: Listing.ListingCategory? = nil // nil = All Categories
    @Published var selectedSortOption: SortOption = .mostRecent
    @Published var selectedStatus: Listing.ListingStatus? = nil // Default to available
    
    // MARK: - Instantly Filtered & Sorted Array
    var filteredAndSortedListings: [Listing] {
        var result = listings
        
        // 1. Filter by Status
        if let status = selectedStatus {
            result = result.filter { $0.status == status }
        }
        
        // 2. Filter by Category
        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }
        
        // 3. Sort Options
        switch selectedSortOption {
        case .mostRecent:
            result.sort { ($0.createdAt ?? Date.distantPast) > ($1.createdAt ?? Date.distantPast) }
        case .priceLowHigh:
            result.sort { $0.priceAsDouble < $1.priceAsDouble }
        case .priceHighLow:
            result.sort { $0.priceAsDouble > $1.priceAsDouble }
        case .free:
            result = result.filter { $0.priceAsDouble == 0.0 }
        }
        
        return result
    }

    // MARK: - Database Actions
    
    func fetchListings() async {
        do {
            let fetchedListings: [Listing] = try await supabase
                .from("listings")
                .select()
                .neq("status", value: "deleted")
                .execute()
                .value
            self.listings = fetchedListings
        } catch {
            print("Error fetching: \(error)")
        }
    }

    func deleteListing(listing: Listing) async {
        guard let id = listing.id else { return }
        do {
            try await supabase.from("listings").update(["status": "deleted"]).eq("id", value: id).execute()
            await fetchListings()
        } catch {
            print("❌ Error soft-deleting listing: \(error)")
        }
    }
    
    func updateListingStatus(listing: Listing, newStatus: Listing.ListingStatus) async {
        guard let id = listing.id else { return }
        do {
            try await supabase.from("listings").update(["status": newStatus.rawValue]).eq("id", value: id).execute()
            await fetchListings()
        } catch {
            print("❌ Error updating status: \(error)")
        }
    }
    
    func uploadImage(_ image: UIImage) async -> String? {
        guard let imageData = image.jpegData(compressionQuality: 0.5) else { return nil }
        let fileName = "\(UUID().uuidString).jpg"
        do {
            try await supabase.storage.from("listingImages").upload(fileName, data: imageData)
            let publicURL = try supabase.storage.from("listingImages").getPublicURL(path: fileName)
            return publicURL.absoluteString
        } catch {
            print("❌ Storage Upload Error: \(error)")
            return nil
        }
    }

    // UPDATED: Now requires a category when posting
    func addListing(title: String, price: String, description: String, userId: UUID, imageUrl: String?, category: Listing.ListingCategory) async {
        let newListing = Listing(title: title, price: price, description: description, imageUrl: imageUrl, userId: userId, status: .available, removalReason: nil, category: category)
        
        do {
            try await supabase.from("listings").insert(newListing).execute()
            await fetchListings()
        } catch {
            print("❌ Supabase Error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Messaging Edge Function
    struct MessagePayload: Codable {
        let sellerId: String
        let buyerEmail: String
        let itemTitle: String
        let message: String
    }
    
    func sendMessage(sellerId: UUID, itemTitle: String, buyerEmail: String, message: String) async -> Bool {
      let payload = MessagePayload(sellerId: sellerId.uuidString.lowercased(), buyerEmail: buyerEmail, itemTitle: itemTitle, message: message)
        let session = try? await supabase.auth.session
        _ = session?.accessToken ?? ""
        do {
            _ = try await supabase.functions.invoke("send-message", options: .init(headers: ["Content-Type": "application/json"], body: payload))
            return true
        } catch {
            print("Error calling send-message: \(error)")
            return false
        }
    }
}
