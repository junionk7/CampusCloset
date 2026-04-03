//
//  Listing.swift
//  CampusCloset
//
//  Created by Jun Kuang on 3/14/26.
//
import Foundation

struct Listing: Identifiable, Codable {
    var id: UUID? = nil //default value
    let title: String
    let price: String
    let description: String
    var imageUrl: String? // Matches 'image_url'
    var createdAt: Date? = nil //default value
    var userId: UUID
    
    var status: String? = "available"
    var removalReason: String? = nil

    enum CodingKeys: String, CodingKey {
        case id, title, price, description
        case imageUrl = "image_url"
        case createdAt = "created_at"
        case userId = "user_id"
        case removalReason = "removal_reason"
    }
    
    
    // NEW HELPER: Formats the raw timestamp into a clean "Date Posted" stamp
        var formattedDate: String {
            guard let createdAt = createdAt else { return "Just now" }
            let formatter = DateFormatter()
            formatter.dateStyle = .medium // e.g., "Oct 24, 2026"
            formatter.timeStyle = .none
            return formatter.string(from: createdAt)
        }
}
