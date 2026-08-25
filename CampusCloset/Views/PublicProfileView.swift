//
//  PublicProfileView.swift
//  CampusCloset
//
//  Created by Jun Kuang on 4/20/26.
//
import SwiftUI
import Supabase

struct PublicProfileView: View {
    /// Name the caller already had (from the listing join or people-search), so
    /// the header reads correctly before the full profile loads.
    let sellerName: String
    let sellerId: UUID

    @EnvironmentObject var listingsVM: ListingsViewModel

    @State private var profile: PublicProfile?

    private var sellerListings: [Listing] { listingsVM.sellerListings(for: sellerId) }
    private var displayName: String { profile?.displayName ?? sellerName }

    let columns = [GridItem(.flexible(), spacing: 15), GridItem(.flexible(), spacing: 15)]

    var body: some View {
        ScrollView {
            VStack(spacing: 25) {

                // MARK: - Header Section
                VStack(spacing: 5) {
                    avatar

                    Text(displayName)
                        .font(.title2)
                        .fontWeight(.bold)

                    if let classYear = profile?.class_year, !classYear.isEmpty {
                        Text(classYear)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    if let dorm = profile?.dorm, !dorm.isEmpty {
                        Label(dorm, systemImage: "house")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Text(profile?.joinedDateText ?? "CampusCloset Member")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 2)

                    if let bio = profile?.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .padding(.top, 4)
                    }
                }
                .padding(.top)

                // MARK: - Stats Row
                HStack(spacing: 60) {
                    VStack {
                        Text("\(listingsVM.activeCount(for: sellerId))")
                            .font(.title3)
                            .fontWeight(.bold)
                        Text("Active")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    VStack {
                        Text("\(listingsVM.soldCount(for: sellerId))")
                            .font(.title3)
                            .fontWeight(.bold)
                        Text("Sold")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 15)
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .cornerRadius(15)
                .padding(.horizontal)

                Divider().padding(.horizontal)

                // MARK: - Post Gallery
                VStack(alignment: .leading) {
                    Text("Posts")
                        .font(.headline)
                        .padding(.horizontal)

                    if sellerListings.isEmpty {
                        ContentUnavailableView("No listings yet", systemImage: "tag.slash")
                            .padding(.top, 30)
                    } else {
                        LazyVGrid(columns: columns, spacing: 15) {
                            ForEach(sellerListings) { listing in
                                NavigationLink(destination: ListingDetailView(listing: listing)) {
                                    ListingGridTile(listing: listing)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.bottom, 30)
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await listingsVM.fetchListings()
            await loadProfile()
        }
        .task {
            await loadProfile()
        }
    }

    @ViewBuilder
    private var avatar: some View {
        if let urlString = profile?.avatar_url, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 90, height: 90)
                        .clipShape(Circle())
                default:
                    avatarPlaceholder
                }
            }
        } else {
            avatarPlaceholder
        }
    }

    private var avatarPlaceholder: some View {
        Image(systemName: "person.crop.circle.fill")
            .resizable()
            .frame(width: 90, height: 90)
            .foregroundColor(.gray)
    }

    private func loadProfile() async {
        do {
            let fetched: PublicProfile = try await supabase
                .from("profiles")
                .select(PublicProfile.selectColumns)
                .eq("id", value: sellerId)
                .single()
                .execute()
                .value
            profile = fetched
        } catch {
            // Header falls back to the name the caller passed in.
            print("❌ Error fetching seller profile: \(error)")
        }
    }
}
