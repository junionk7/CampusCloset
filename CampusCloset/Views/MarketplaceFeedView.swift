import SwiftUI
import Auth

struct MarketplaceFeedView: View {
    @EnvironmentObject var listingsVM: ListingsViewModel
    @EnvironmentObject var authVM: AuthViewModel

    @State private var searchText = ""
    @State private var listingToEdit: Listing? = nil
    
    // NEW: Computed property to handle the search logic dynamically
    var searchResults: [Listing] {
        if searchText.isEmpty {
            return listingsVM.filteredAndSortedListings
        } else {
            return listingsVM.filteredAndSortedListings.filter { listing in
                listing.title.localizedCaseInsensitiveContains(searchText) ||
                listing.description.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            
            // MARK: - Compact Filter Bar (Top Right)
            HStack(spacing: 12) {
                Spacer() // Pushes the menus to the right
                
                // 1. Category Menu
                Menu {
                    Button("All Categories") { listingsVM.selectedCategory = nil }
                    Divider()
                    ForEach(Listing.ListingCategory.allCases, id: \.self) { cat in
                        Button(cat.displayName) { listingsVM.selectedCategory = cat }
                    }
                } label: {
                    FilterBadge(text: listingsVM.selectedCategory?.displayName ?? "Category")
                }
                
                // 2. Sort Menu
                Menu {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Button(option.rawValue) { listingsVM.selectedSortOption = option }
                    }
                } label: {
                    FilterBadge(text: listingsVM.selectedSortOption.rawValue)
                }
                
                // 3. Status Menu (Top Right)
                Menu {
                    Button("All Statuses") { listingsVM.selectedStatus = nil }
                    Divider()
                    ForEach(Listing.ListingStatus.allCases, id: \.self) { status in
                        Button(status.displayName) { listingsVM.selectedStatus = status }
                    }
                } label: {
                    FilterBadge(text: listingsVM.selectedStatus?.displayName ?? "All Statuses")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .shadow(color: Color.black.opacity(0.05), radius: 2, y: 2)
            
            // MARK: - The Feed
            // UPDATED: Now uses searchResults instead of filteredAndSortedListings directly
            List(searchResults) { listing in
                ZStack(alignment: .topLeading) {
                NavigationLink(destination: ListingDetailView(listing: listing)) {
                    VStack(alignment: .leading, spacing: 8) {
                        ZStack {
                            // Image selection
                            if let urlString = listing.displayImageUrl, let url = URL(string: urlString) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image.resizable().scaledToFill().frame(height: 180).clipped()
                                    case .failure:
                                        Image(systemName: "photo").font(.largeTitle).frame(height: 180).frame(maxWidth: .infinity).background(Color.gray.opacity(0.1))
                                    case .empty:
                                        ProgressView().frame(height: 180).frame(maxWidth: .infinity)
                                    @unknown default:
                                        EmptyView()
                                    }
                                }.cornerRadius(8)
                            } else {
                                Rectangle().fill(Color.gray.opacity(0.3)).frame(height: 180).cornerRadius(8).overlay(Text("No Image").foregroundColor(.gray))
                            }
                            
                            // Badges (Status & Category) — top right
                            VStack {
                                HStack {
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text(listing.status.displayName)
                                            .font(.caption2).fontWeight(.bold).foregroundColor(.white)
                                            .padding(.horizontal, 8).padding(.vertical, 4)
                                            .background(statusColor(listing.status)).cornerRadius(4)
                                        Text(listing.category.displayName)
                                            .font(.caption2).fontWeight(.bold).foregroundColor(.black)
                                            .padding(.horizontal, 8).padding(.vertical, 4)
                                            .background(Color.white.opacity(0.9)).cornerRadius(4)
                                    }
                                }
                                Spacer()
                            }
                            .padding(8)

                        }
                        
                        Text(listing.title).font(.headline)
                        
                        // UPDATED: Added HStack to put Price on left, Name on right
                        HStack {
                            if listing.priceAsDouble == 0 {
                                Text("FREE")
                                    .font(.caption).fontWeight(.heavy)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(Color.green)
                                    .cornerRadius(6)
                            } else {
                                Text("$\(listing.price)").foregroundColor(.green).fontWeight(.semibold)
                            }
                            Spacer()
                            // Displays Seller Name
                            Text("By \(listing.profiles?.full_name ?? "Unknown Seller")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Text(listing.description).font(.subheadline).foregroundColor(.gray).lineLimit(2)
                    }
                    .padding().background(Color.white).cornerRadius(10).shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                }
                if listing.userId == authVM.currentUser?.id {
                    Button {
                        listingToEdit = listing
                    } label: {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                            .background(Color.blue.clipShape(Circle()))
                    }
                    .buttonStyle(.plain)
                    .contentShape(Circle())
                    .padding([.top, .leading], 20)
                }
                } // end outer ZStack
                .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            // NEW: Native SwiftUI Search Modifier
            .searchable(text: $searchText, prompt: "Search listings...")
            .task {
                await listingsVM.fetchListings()
            }
            .sheet(item: $listingToEdit) { listing in
                EditListingView(listing: listing)
                    .environmentObject(listingsVM)
                    .environmentObject(authVM)
            }
        }
    }
    
    private func statusColor(_ status: Listing.ListingStatus) -> Color {
        switch status {
        case .available: return .green
        case .sold: return .orange
        case .unavailable: return .gray
        }
    }
}

// Helper view to make the menu buttons look like little badges
struct FilterBadge: View {
    let text: String
    var body: some View {
        HStack(spacing: 4) {
            Text(text).lineLimit(1)
            Image(systemName: "chevron.down").font(.system(size: 10))
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.systemGray5))
        .foregroundColor(.primary)
        .cornerRadius(12)
    }
}
