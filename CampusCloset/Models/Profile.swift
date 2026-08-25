//
//  Profile.swift
//  CampusCloset
//

import Foundation

/// A profile row as other students see it — the seller header on
/// `PublicProfileView`. Field names match the Postgres columns directly, the
/// same convention `ProfileData` in AuthViewModel uses.
struct PublicProfile: Codable {
    let id: UUID
    let full_name: String?
    let dorm: String?
    let class_year: String?
    let bio: String?
    let avatar_url: String?
    let joined_at: String?

    /// Columns to request from `profiles`. Kept next to the struct so the
    /// select and the decoder can't fall out of sync.
    static let selectColumns = "id, full_name, dorm, class_year, bio, avatar_url, joined_at"

    var displayName: String {
        guard let name = full_name, !name.isEmpty else { return "Unknown Seller" }
        return name
    }

    var joinedDateText: String {
        PublicProfile.formatJoinDate(joined_at)
    }

    /// Supabase returns `joined_at` as an ISO-8601 string that may or may not
    /// carry fractional seconds, so both shapes are attempted.
    static func formatJoinDate(_ isoString: String?, fallback: String = "Recently joined") -> String {
        guard let isoString else { return fallback }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var date = formatter.date(from: isoString)
        if date == nil {
            formatter.formatOptions = [.withInternetDateTime]
            date = formatter.date(from: isoString)
        }

        guard let validDate = date else { return fallback }

        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "'Joined' MMM yyyy"
        return displayFormatter.string(from: validDate)
    }
}
