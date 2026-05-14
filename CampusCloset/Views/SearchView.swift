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

    let scopes = ["Listings", "People"]

    var filteredListings: [Listing] {
        if searchText.isEmpty {
            return listingsVM.listings
        } else {
            return listingsVM.listings.filter {
                $0.title.lowercased().contains(searchText.lowercased())
            }
        }
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
                    ForEach(filteredListings) { listing in
                        NavigationLink(destination: ListingDetailView(listing: listing)) {
                            VStack(alignment: .leading) {
                                Text(listing.title)
                                    .font(.headline)
                                Text(listing.price)
                                    .foregroundColor(.green)
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
            .onChange(of: searchText) { _, newValue in
                if searchScope == "People" {
                    Task { await searchUsers(query: newValue) }
                }
            }
            .onChange(of: searchScope) { _, _ in
                if searchScope == "People" {
                    Task { await searchUsers(query: searchText) }
                }
            }
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
                .ilike("full_name", value: "%\(query)%")
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
