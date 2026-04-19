import SwiftUI

struct MarketplaceFeedView: View {
    @EnvironmentObject var listingsVM: ListingsViewModel
    
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
                    // Option 1: All Statuses
                    Button("All Statuses") {
                        listingsVM.selectedStatus = nil
                    }
                    
                    Divider()
                    
                    // Options 2, 3, 4: Available, Sold, Unavailable
                    ForEach(Listing.ListingStatus.allCases, id: \.self) { status in
                        Button(status.displayName) {
                            listingsVM.selectedStatus = status
                        }
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
            List(listingsVM.filteredAndSortedListings) { listing in
                NavigationLink(destination: ListingDetailView(listing: listing)) {
                    VStack(alignment: .leading, spacing: 8) {
                        ZStack(alignment: .topTrailing) {
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
                            
                            // Badges (Status & Category)
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
                            .padding(8)
                        }
                        
                        Text(listing.title).font(.headline)
                        Text(listing.price).foregroundColor(.green).fontWeight(.semibold)
                        Text(listing.description).font(.subheadline).foregroundColor(.gray).lineLimit(2)
                    }
                    .padding().background(Color.white).cornerRadius(10).shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                }
                .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .task {
                await listingsVM.fetchListings()
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
