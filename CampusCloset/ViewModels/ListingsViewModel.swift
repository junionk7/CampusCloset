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

enum SortOption: String, CaseIterable {
    case mostRecent = "Most Recent"
    case priceLowHigh = "Price (L-H)"
    case priceHighLow = "Price (H-L)"
    case free = "Free"
}

@MainActor
class ListingsViewModel: ObservableObject {
    @Published var listings: [Listing] = []

    @Published var blockedUserIds: [UUID] = []

    // Listing ids the current user has saved. Backed by the `favorites` table
    // (see supabase/favorites.sql).
    @Published var favoriteListingIds: Set<UUID> = []

    @Published var selectedCategory: Listing.ListingCategory? = nil
    @Published var selectedSortOption: SortOption = .mostRecent
    @Published var selectedStatus: Listing.ListingStatus? = nil

    var filteredAndSortedListings: [Listing] {
        var result = listings
        
        if let status = selectedStatus { result = result.filter { $0.status == status } }
        if let category = selectedCategory { result = result.filter { $0.category == category } }
        
        switch selectedSortOption {
        case .mostRecent: result.sort { ($0.createdAt ?? Date.distantPast) > ($1.createdAt ?? Date.distantPast) }
        case .priceLowHigh: result.sort { $0.priceAsDouble < $1.priceAsDouble }
        case .priceHighLow: result.sort { $0.priceAsDouble > $1.priceAsDouble }
        case .free: result = result.filter { $0.priceAsDouble == 0.0 }
        }
        return result
    }

    func fetchBlockedUsers() async {
            guard let currentUserId = supabase.auth.currentUser?.id else { return }
            do {
                struct BlockedUser: Codable { let blocked_id: UUID }
                let blocks: [BlockedUser] = try await supabase
                    .from("blocked_users")
                    .select("blocked_id")
                    .eq("blocker_id", value: currentUserId)
                    .execute()
                    .value
                
                DispatchQueue.main.async {
                    self.blockedUserIds = blocks.map { $0.blocked_id }
                }
            } catch {
                print("Error fetching blocked users: \(error)")
            }
        }

        func fetchListings() async {
            await fetchBlockedUsers() // Fetch blocked users first
            await fetchFavorites()    // Keep the hearts in sync with the feed
            do {
                let fetchedListings: [Listing] = try await supabase
                    .from("listings")
                    .select("""
                        *,
                        profiles!user_id (full_name)
                    """)
                    .neq("status", value: "deleted")
                    .execute()
                    .value

                DispatchQueue.main.async {
                    // Instantly filter out posts from people the user has blocked
                    self.listings = fetchedListings.filter { !self.blockedUserIds.contains($0.userId) }
                }
            } catch {
                print("❌ Error fetching listings: \(error)")
            }
        }

    // MARK: - Saved Items (Favorites)

    /// The user's saved listings, in current feed order. Anything sold, deleted
    /// or posted by a blocked user falls out on its own, because this filters
    /// against `listings` rather than holding its own copies.
    var favoriteListings: [Listing] {
        listings.filter { listing in
            guard let id = listing.id else { return false }
            return favoriteListingIds.contains(id)
        }
    }

    func isFavorite(_ listing: Listing) -> Bool {
        guard let id = listing.id else { return false }
        return favoriteListingIds.contains(id)
    }

    func fetchFavorites() async {
        guard let userId = supabase.auth.currentUser?.id else { return }
        do {
            struct FavoriteRow: Codable { let listing_id: UUID }
            let rows: [FavoriteRow] = try await supabase
                .from("favorites")
                .select("listing_id")
                .eq("user_id", value: userId)
                .execute()
                .value

            self.favoriteListingIds = Set(rows.map { $0.listing_id })
        } catch {
            print("❌ Error fetching favorites: \(error)")
        }
    }

    /// Flips the heart immediately, then puts it back if the write fails, so the
    /// icon never claims a save that didn't land.
    func toggleFavorite(_ listing: Listing) async {
        guard let listingId = listing.id,
              let userId = supabase.auth.currentUser?.id else { return }

        let wasFavorite = favoriteListingIds.contains(listingId)
        if wasFavorite {
            favoriteListingIds.remove(listingId)
        } else {
            favoriteListingIds.insert(listingId)
        }

        do {
            if wasFavorite {
                try await supabase.from("favorites")
                    .delete()
                    .eq("user_id", value: userId)
                    .eq("listing_id", value: listingId)
                    .execute()
            } else {
                struct FavoriteInsert: Encodable {
                    let user_id: UUID
                    let listing_id: UUID
                }
                try await supabase.from("favorites")
                    .insert(FavoriteInsert(user_id: userId, listing_id: listingId))
                    .execute()
            }
        } catch {
            print("❌ Error toggling favorite: \(error)")
            if wasFavorite {
                favoriteListingIds.insert(listingId)
            } else {
                favoriteListingIds.remove(listingId)
            }
        }
    }

    // MARK: - Profile Stats

    /// Every non-deleted listing by a seller, newest first — what their profile
    /// gallery shows, sold items included.
    func sellerListings(for userId: UUID) -> [Listing] {
        listings
            .filter { $0.userId == userId }
            .sorted { ($0.createdAt ?? Date.distantPast) > ($1.createdAt ?? Date.distantPast) }
    }

    func activeCount(for userId: UUID) -> Int {
        listings.filter { $0.userId == userId && $0.status == .available }.count
    }

    func soldCount(for userId: UUID) -> Int {
        listings.filter { $0.userId == userId && $0.status == .sold }.count
    }

        func reportListing(listingId: UUID, reason: String) async -> Bool {
            guard let reporterId = supabase.auth.currentUser?.id else { return false }
            do {
                struct ReportData: Encodable {
                    let reporter_id: UUID
                    let listing_id: UUID
                    let reason: String
                }
                let report = ReportData(reporter_id: reporterId, listing_id: listingId, reason: reason)
                try await supabase.from("reports").insert(report).execute()
                return true
            } catch {
                print("❌ Error reporting listing: \(error)")
                return false
            }
        }

        func blockUser(blockedId: UUID) async -> Bool {
            guard let blockerId = supabase.auth.currentUser?.id else { return false }
            do {
                struct BlockData: Encodable {
                    let blocker_id: UUID
                    let blocked_id: UUID
                }
                let block = BlockData(blocker_id: blockerId, blocked_id: blockedId)
                try await supabase.from("blocked_users").insert(block).execute()
                
                // Refresh feed immediately to hide their posts
                await fetchListings()
                return true
            } catch {
                print("❌ Error blocking user: \(error)")
                return false
            }
        }

    func updateListing(listing: Listing, title: String, price: String, description: String, category: Listing.ListingCategory, imageUrls: [String]) async {
        guard let id = listing.id else { return }
        struct ListingUpdate: Encodable {
            let title: String
            let price: String
            let description: String
            let category: String
            let image_urls: [String]
        }
        let payload = ListingUpdate(title: title, price: price, description: description, category: category.rawValue, image_urls: imageUrls)
        do {
            try await supabase.from("listings")
                .update(payload)
                .eq("id", value: id)
                .execute()
            await fetchListings()
        } catch { print("❌ Error updating listing: \(error)") }
    }

    func deleteListing(listing: Listing) async {
        guard let id = listing.id else { return }
        do {
            try await supabase.from("listings").update(["status": "deleted"]).eq("id", value: id).execute()
            await fetchListings()
        } catch { print("❌ Error soft-deleting listing: \(error)") }
    }
    
    func updateListingStatus(listing: Listing, newStatus: Listing.ListingStatus) async {
        guard let id = listing.id else { return }
        do {
            try await supabase.from("listings").update(["status": newStatus.rawValue]).eq("id", value: id).execute()
            await fetchListings()
        } catch { print("❌ Error updating status: \(error)") }
    }
    
    // Base upload function for a single image
    func uploadImage(_ image: UIImage) async -> String? {
        guard let imageData = image.jpegData(compressionQuality: 0.5) else { return nil }
        let fileName = "\(UUID().uuidString).jpg"
        do {
            try await supabase.storage.from("listingImages").upload(fileName, data: imageData)
            return try supabase.storage.from("listingImages").getPublicURL(path: fileName).absoluteString
        } catch {
            print("❌ Storage Upload Error: \(error)")
            return nil
        }
    }
    
    // NEW: Batch upload function for multiple images
    func uploadImages(images: [UIImage]) async -> [String] {
        var uploadedURLs: [String] = []
        for image in images {
            if let url = await uploadImage(image) {
                uploadedURLs.append(url)
            }
        }
        return uploadedURLs
    }

    // UPDATED: Now accepts an array of imageUrls
        func addListing(title: String, price: String, description: String, userId: UUID, imageUrls: [String], category: Listing.ListingCategory) async {
            let newListing = Listing(
                title: title,
                price: price,
                description: description,
                imageUrls: imageUrls, // Only passing the new array
                userId: userId,
                status: .available,
                removalReason: nil,
                category: category
            )
            
            do {
                try await supabase.from("listings").insert(newListing).execute()
                await fetchListings()
            } catch {
                print("❌ Supabase Error: \(error.localizedDescription)")
            }
        }
    
    struct MessagePayload: Codable {
        let listingId: String
        let message: String
    }

    // Sends a buyer's message to a seller via the `send-message` Edge Function.
    // The function derives the buyer's identity from the auth JWT, looks up the
    // seller from the listing, and creates BOTH in-app notifications server-side.
    // No identity or notification data is trusted from the client. [Fixes #2, #7]
    func sendMessage(listingId: UUID, message: String) async -> Bool {
        let payload = MessagePayload(listingId: listingId.uuidString.lowercased(), message: message)
        do {
            _ = try await supabase.functions.invoke("send-message", options: .init(headers: ["Content-Type": "application/json"], body: payload))
            return true
        } catch {
            print("❌ Error sending message: \(error)")
            return false
        }
    }
}
