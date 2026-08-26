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
    
    // Array for multiple images
    var imageUrls: [String]?

    // Small (~400px) versions of imageUrls, same order, one per photo. Every
    // browsing surface reads these instead of the full-size originals — see
    // displayThumbnailUrl. Null on listings posted before thumbnails existed.
    var thumbnailUrls: [String]?

    var createdAt: Date? = nil
    var userId: UUID
    var status: ListingStatus = .available
    var removalReason: String? = nil
    var category: ListingCategory
    
    // NEW: Nested struct to catch the joined profile data
    var profiles: SellerProfile?
    
    struct SellerProfile: Codable {
        let full_name: String?
    }
    
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
        case electronics = "Electronics"
        case dorm = "Dorm & Room"
        case sports = "Sports & Outdoors"
        case games = "Games & Entertainment"
        case other = "Other"

        var displayName: String { self.rawValue }
    }
    
    enum CodingKeys: String, CodingKey {
        case id, title, price, description
        case imageUrls = "image_urls" // NEW Mapping
        case thumbnailUrls = "thumbnail_urls"
        case createdAt = "created_at"
        case userId = "user_id"
        case status
        case removalReason = "removal_reason"
        case category
        case profiles // NEW Mapping for the joined data
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

    // Price as it should read on screen, everywhere.
    var displayPrice: String {
        priceAsDouble == 0 ? "Free" : "$\(price)"
    }

    // NEW HELPER: Safely gets the first image from the array
    var displayImageUrl: String? {
        return imageUrls?.first
    }

    /// What every browsing surface — the feed, search rows, profile grids —
    /// should load. Falls back to the full-size photo for listings posted before
    /// thumbnails existed, or if a thumbnail failed to upload, so a missing
    /// thumbnail costs bandwidth rather than showing an empty tile.
    var displayThumbnailUrl: String? {
        return thumbnailUrls?.first ?? imageUrls?.first
    }

    /// The thumbnail matching `imageUrls[index]`, falling back to the original.
    /// Used by the edit screen's photo strip.
    func thumbnailUrl(at index: Int) -> String? {
        if let thumbnails = thumbnailUrls, thumbnails.indices.contains(index) {
            return thumbnails[index]
        }
        guard let images = imageUrls, images.indices.contains(index) else { return nil }
        return images[index]
    }

    // The one search predicate, shared by the Marketplace feed and the Search
    // tab so the two can't drift apart. An empty query matches everything.
    func matches(searchQuery query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        return title.localizedCaseInsensitiveContains(trimmed)
            || description.localizedCaseInsensitiveContains(trimmed)
    }
}
