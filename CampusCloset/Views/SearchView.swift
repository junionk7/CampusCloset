//
//  SearchView.swift
//  CampusCloset
//
//  Created by Jun Kuang on 3/16/26.
//

import SwiftUI
import Supabase

private struct UserResult: Identifiable {
    let id: UUID
    let name: String
}

struct SearchView: View {

    @EnvironmentObject var listingsVM: ListingsViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var searchText = ""
    @State private var searchScope = "Listings"
    @State private var userResults: [UserResult] = []
    @State private var isSearchingUsers = false

    /// In-flight people search. Held so each keystroke can cancel the last one
    /// instead of firing a query per character.
    @State private var userSearchTask: Task<Void, Never>? = nil

    let scopes = ["Listings", "People"]

    // Same predicate the Marketplace feed uses, so a query that finds an item
    // there finds it here too. The feed's category/sort/status pickers are
    // deliberately not applied — those belong to that tab.
    var filteredListings: [Listing] {
        listingsVM.listings.filter { $0.matches(searchQuery: searchText) }
    }

    var body: some View {
        NavigationStack {
            Picker("Scope", selection: $searchScope) {
                ForEach(scopes, id: \.self) { Text($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            List {
                if searchScope == "Listings" {
                    if filteredListings.isEmpty && !searchText.isEmpty {
                        Text("No listings found")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(filteredListings) { listing in
                            NavigationLink(destination: ListingDetailView(listing: listing)) {
                                HStack(spacing: 12) {
                                    thumbnail(for: listing)

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(listing.title)
                                            .font(.headline)
                                            .lineLimit(1)
                                        Text(listing.displayPrice)
                                            .foregroundColor(.green)
                                            .font(.subheadline)
                                        Text(listing.category.displayName)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    if isSearchingUsers {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else if userResults.isEmpty && !searchText.isEmpty {
                        Text("No users found")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(userResults) { user in
                            NavigationLink(destination: PublicProfileView(sellerName: user.name, sellerId: user.id)) {
                                HStack(spacing: 12) {
                                    Image(systemName: "person.crop.circle.fill")
                                        .font(.system(size: 36))
                                        .foregroundColor(.gray)
                                    Text(user.name)
                                        .font(.headline)
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: searchScope == "Listings" ? "Search listings..." : "Search people...")
            .navigationTitle("Search")
            .refreshable {
                await listingsVM.fetchListings(force: true)
                if searchScope == "People" { await searchUsers(query: searchText) }
            }
            .onChange(of: searchText) { _, newValue in
                if searchScope == "People" {
                    scheduleUserSearch(query: newValue)
                }
            }
            .onChange(of: searchScope) { _, _ in
                if searchScope == "People" {
                    scheduleUserSearch(query: searchText)
                }
            }
        }
    }

    @ViewBuilder
    private func thumbnail(for listing: Listing) -> some View {
        // 54pt row image — the thumbnail, never the full-size photo.
        if let urlString = listing.displayThumbnailUrl, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    Color.gray.opacity(0.2)
                }
            }
            .frame(width: 54, height: 54)
            .clipped()
            .cornerRadius(8)
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 54, height: 54)
                .overlay(Image(systemName: "photo").foregroundColor(.gray))
        }
    }

    /// Waits out a short pause in typing before querying, so "jun kuang" costs
    /// one request instead of nine.
    private func scheduleUserSearch(query: String) {
        userSearchTask?.cancel()
        userSearchTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            await searchUsers(query: query)
        }
    }

    private func searchUsers(query: String) async {
        guard !query.isEmpty else {
            userResults = []
            return
        }
        isSearchingUsers = true
        defer { isSearchingUsers = false }
        do {
            struct ProfileRow: Codable {
                let id: UUID
                let full_name: String?
            }
            let rows: [ProfileRow] = try await supabase
                .from("profiles")
                .select("id, full_name")
                .ilike("full_name", pattern: "%\(query)%")
                .execute()
                .value
            userResults = rows.compactMap { row in
                guard let name = row.full_name, row.id != authViewModel.currentUser?.id else { return nil }
                return UserResult(id: row.id, name: name)
            }
        } catch {
            print("User search error: \(error)")
        }
    }
}

#Preview {
    SearchView()
        .environmentObject(ListingsViewModel())
        .environmentObject(AuthViewModel())
}
