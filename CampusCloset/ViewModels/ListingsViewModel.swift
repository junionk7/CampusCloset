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


@MainActor
class ListingsViewModel: ObservableObject {
    @Published var listings: [Listing] = []

    
    
    // Fetch from Supabase
    // 1. Update fetchListings to only show available items
    func fetchListings() async {
        do {
            let fetchedListings: [Listing] = try await supabase
                .from("listings")
                .select()
                .neq("status", value: "deleted") // Added this filter
                .execute()
                .value
            
            self.listings = fetchedListings
        } catch {
            print("Error fetching: \(error)")
        }
    }

    // 2. Add this new function for Soft Deleting
    func deleteListing(listing: Listing) async {
        guard let id = listing.id else { return }
        
        do {
            // We perform an UPDATE, not a DELETE, to keep data for stats
            try await supabase
                .from("listings")
                .update(["status": "deleted"])
                .eq("id", value: id)
                .execute()
            
            print("✅ Listing marked as deleted in Supabase")
            
            // Refresh the feed immediately
            await fetchListings()
        } catch {
            print("❌ Error soft-deleting listing: \(error)")
        }
    }
    
    //Update status
    func updateListingStatus(listing: Listing, newStatus: Listing.ListingStatus) async {
            guard let id = listing.id else { return }
            
            do {
                // Updating the EXISTING 'status' column
                try await supabase
                    .from("listings")
                    .update(["status": newStatus.rawValue])
                    .eq("id", value: id)
                    .execute()
                
                await fetchListings()
            } catch {
                print("❌ Error updating status: \(error)")
            }
        }
    
    
    
    
    
    // 1. New Function: Upload the photo to Supabase Storage
        func uploadImage(_ image: UIImage) async -> String? {
            // Convert the image to data (compress it so it's not too huge)
            guard let imageData = image.jpegData(compressionQuality: 0.5) else { return nil }
            
            // Create a unique name for the file
            let fileName = "\(UUID().uuidString).jpg"
            
            do {
                // Upload to the bucket you created in the dashboard
                try await supabase.storage
                    .from("listingImages") // Make sure this matches your bucket name exactly!
                    .upload(fileName, data: imageData)
                
                // Get the public link for that file
                let publicURL = try supabase.storage
                    .from("listingImages")
                    .getPublicURL(path: fileName)
                
                return publicURL.absoluteString
            } catch {
                print("❌ Storage Upload Error: \(error)")
                return nil
            }
        }

    // Post to Supabase
    func addListing(title: String, price: String, description: String, userId:UUID, imageUrl: String?) async {
        let newListing = Listing(title: title, price: price, description: description, imageUrl: imageUrl, userId: userId, status: .available, removalReason: nil)
        
        do {
            try await supabase
                .from("listings") // Matches your table name
                .insert(newListing)
                .execute()
            
            print("✅ Successfully posted to Supabase!")
            // Refresh the list so the new item shows up immediately
            await fetchListings()
        } catch {
            print("❌ Supabase Error: \(error.localizedDescription)")
        }
    }
    
    
//Below is the process used for E-mailing sellers/buyers
    
    struct MessagePayload: Codable {
        let sellerId: String   //changed to string because this is what Edge Functions is expecting?
        let buyerEmail: String
        let itemTitle: String
        let message: String

        // Add this to map Swift names to what the Edge Function expects
        enum CodingKeys: String, CodingKey {
            case sellerId = "sellerId"
            case buyerEmail = "buyerEmail"
            case itemTitle = "itemTitle"
            case message = "message"
        }
    }
    
    // Call the Supabase Edge Function
    func sendMessage(sellerId: UUID, itemTitle: String, buyerEmail: String, message: String) async -> Bool {
      let payload = MessagePayload(
            sellerId: sellerId.uuidString.lowercased(),
            buyerEmail: buyerEmail,
            itemTitle: itemTitle,
            message: message
        )
        
        let session = try? await supabase.auth.session
        _ = session?.accessToken ?? ""
        

        do {
                // use '_ =' to say we don't need to save the result of this call
                _ = try await supabase.functions.invoke(
                    "send-message",
                    options: .init(
                        headers: ["Content-Type": "application/json"],
                        body: payload
                    )
                )
                return true
            } catch {
                //  keep this one print just in case something breaks in the future
                print("Error calling send-message: \(error)")
                return false
            }
    }
    
}
