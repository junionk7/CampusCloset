//
//  Listing.swift
//  CampusCloset
//
//  Created by Jun Kuang on 3/14/26.
//
import Foundation

//data structure of a listing
import Foundation

struct Listing: Identifiable, Codable {
    var id: UUID? = UUID() // Matches 'id'
    let title: String
    let price: String
    let description: String
    var imageUrl: String? = nil // Matches 'image_url'
    var createdAt: Date? = Date() // Matches 'created_at'
    var userId: UUID? = nil // Matches 'user_id'

    enum CodingKeys: String, CodingKey {
        case id, title, price, description
        case imageUrl = "image_url"
        case createdAt = "created_at"
        case userId = "user_id"
    }
}
