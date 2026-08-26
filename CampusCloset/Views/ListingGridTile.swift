//
//  ListingGridTile.swift
//  CampusCloset
//

import SwiftUI

/// A square listing tile for the profile galleries, with a status badge so a
/// sold item reads as sold at a glance. Shared by ProfileView and
/// PublicProfileView.
struct ListingGridTile: View {
    let listing: Listing

    /// Bumping this gives the AsyncImage a fresh identity, which re-issues the
    /// request. See the `.failure` branch below.
    @State private var loadAttempt = 0
    private let maxLoadAttempts = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack(alignment: .topLeading) {
                thumbnail

                if listing.status != .available {
                    Text(listing.status.displayName.uppercased())
                        .font(.caption2).fontWeight(.heavy)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(listing.status == .sold ? Color.orange : Color.gray)
                        .cornerRadius(4)
                        .padding(6)
                }
            }

            Text(listing.title)
                .font(.caption)
                .fontWeight(.bold)
                .lineLimit(1)
                .foregroundColor(.primary)

            Text(listing.displayPrice)
                .font(.caption2)
                .foregroundColor(.green)
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        // 120pt tile — the thumbnail is the right size for it, and the full-size
        // photo is not.
        if let urlString = listing.displayThumbnailUrl, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(height: 120)
                        .clipped()
                        .cornerRadius(10)
                case .empty:
                    loading
                case .failure:
                    // A tile scrolling through a LazyVGrid can have its request
                    // cancelled, and AsyncImage never retries on its own — which
                    // left listings that DO have photos showing "no photo"
                    // forever. Re-issue with a fresh identity, a bounded number
                    // of times, before admitting defeat.
                    if loadAttempt < maxLoadAttempts {
                        loading.task {
                            try? await Task.sleep(for: .milliseconds(300))
                            loadAttempt += 1
                        }
                    } else {
                        placeholder
                    }
                @unknown default:
                    placeholder
                }
            }
            .id(loadAttempt)
        } else {
            placeholder
        }
    }

    private var loading: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.gray.opacity(0.2))
            .frame(height: 120)
            .overlay(ProgressView())
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.gray.opacity(0.2))
            .frame(height: 120)
            .overlay(Image(systemName: "photo").foregroundColor(.gray))
    }
}
