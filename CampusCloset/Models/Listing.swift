//
//  Listing.swift
//  CampusCloset
//
//  Created by Jun Kuang on 3/14/26.
//
import Foundation

struct Listing: Identifiable, Codable {
    var id: UUID? = nil
    let title: String
    let price: String
    let description: String
    
    //Array for multiple images
    var imageUrls: [String]?
    
    var createdAt: Date? = nil
    var userId: UUID
    var status: ListingStatus = .available
    var removalReason: String? = nil
    var category: ListingCategory
    
    enum ListingStatus: String, Codable, CaseIterable {
        case available = "available"
        case sold = "sold"
        case unavailable = "unavailable"
            
        var displayName: String { self.rawValue.capitalized }
    }
    
    enum ListingCategory: String, Codable, CaseIterable {
        case clothing = "Clothing"
        case school = "School"
        case appliances = "Appliances"
        case other = "Other"
        
        var displayName: String { self.rawValue }
    }
    
    enum CodingKeys: String, CodingKey {
        case id, title, price, description
        case imageUrls = "image_urls" // NEW Mapping
        case createdAt = "created_at"
        case userId = "user_id"
        case status
        case removalReason = "removal_reason"
        case category
    }
    
    var formattedDate: String {
        guard let createdAt = createdAt else { return "Just now" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: createdAt)
    }
    
    var priceAsDouble: Double {
        let cleanPrice = price.replacingOccurrences(of: "$", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanPrice.lowercased() == "free" { return 0.0 }
        return Double(cleanPrice) ?? 0.0
    }
    
    // NEW HELPER: Safely gets the first image from the array
    var displayImageUrl: String? {
        return imageUrls?.first
    }
}
