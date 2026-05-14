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
        let sellerId: String
        let buyerEmail: String
        let itemTitle: String
        let message: String
    }
    
    func sendMessage(sellerId: UUID, itemTitle: String, buyerEmail: String, message: String) async -> Bool {
        let payload = MessagePayload(sellerId: sellerId.uuidString.lowercased(), buyerEmail: buyerEmail, itemTitle: itemTitle, message: message)
        do {
            _ = try await supabase.functions.invoke("send-message", options: .init(headers: ["Content-Type": "application/json"], body: payload))
        } catch { return false }

        guard let buyerId = supabase.auth.currentUser?.id else { return true }

        struct NotifInsert: Encodable {
            let user_id: UUID
            let type: String
            let title: String
            let body: String
        }

        let senderNotif = NotifInsert(
            user_id: buyerId,
            type: "message_sent",
            title: "Message Sent",
            body: "Your message about '\(itemTitle)' was delivered to the seller's email inbox. You'll get a notification here when they reply."
        )
        let sellerNotif = NotifInsert(
            user_id: sellerId,
            type: "message_received",
            title: "New Interest in Your Listing",
            body: "\(buyerEmail) is interested in your listing '\(itemTitle)' and has sent you an email. Reply to connect with them!"
        )

        do {
            try await supabase.from("notifications").insert(senderNotif).execute()
            try await supabase.from("notifications").insert(sellerNotif).execute()
        } catch {
            print("❌ Error inserting notifications: \(error)")
        }
        return true
    }
}
