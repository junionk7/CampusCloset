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
        let newListing = Listing(title: title, price: price, description: description, imageUrl: imageUrl, userId: userId)
        
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
        

        do {
                // use '_ =' to say we don't need to save the result of this call
                _ = try await supabase.functions.invoke(
                    "send-message",
                    options: .init(body: payload)
                )
                return true
            } catch {
                //  keep this one print just in case something breaks in the future
                print("Error calling send-message: \(error)")
                return false
            }
    }
}
