//
//  FavoriteButton.swift
//  CampusCloset
//

import SwiftUI

/// The heart that saves a listing. Used on the feed card and in the listing
/// detail toolbar, so both spots stay in sync with one another.
struct FavoriteButton: View {
    let listing: Listing
    var size: CGFloat = 22
    /// `.overlay` sits on top of a photo (white heart + shadow); `.plain` sits
    /// on a normal background, such as the detail-view toolbar.
    var style: Style = .overlay

    enum Style { case overlay, plain }

    @EnvironmentObject var listingsVM: ListingsViewModel

    private var isSaved: Bool { listingsVM.isFavorite(listing) }

    private var unsavedColor: Color {
        style == .overlay ? .white : .blue
    }

    var body: some View {
        Button {
            Task { await listingsVM.toggleFavorite(listing) }
        } label: {
            Image(systemName: isSaved ? "heart.fill" : "heart")
                .font(.system(size: size, weight: .semibold))
                .foregroundColor(isSaved ? .red : unsavedColor)
                .symbolEffect(.bounce, value: isSaved)
                .padding(8)
                // A photo can be any colour, so the overlay heart carries its
                // own scrim rather than relying on contrast with the image.
                .background {
                    if style == .overlay {
                        Circle().fill(Color.black.opacity(0.35))
                    }
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isSaved ? "Remove from saved" : "Save listing")
    }
}
