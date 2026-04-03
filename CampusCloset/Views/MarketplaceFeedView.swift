import SwiftUI

struct MarketplaceFeedView: View {

    @EnvironmentObject var listingsVM: ListingsViewModel
    

    var body: some View {
        List(listingsVM.listings) { listing in
            NavigationLink(destination: ListingDetailView(listing: listing)) {
                
                VStack(alignment: .leading, spacing: 8) {
                    
                    
                    // Image selection
                    
                    if let urlString = listing.imageUrl, let url = URL(string: urlString) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill() // Fills the frame without stretching
                                    .frame(height: 180) // Made it slightly taller for better visibility
                                    .clipped() // Cuts off any overflow from scaledToFill
                            case .failure:
                                // If the image fails to load, show a placeholder icon
                                Image(systemName: "photo")
                                    .font(.largeTitle)
                                    .frame(height: 180)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.gray.opacity(0.1))
                            case .empty:
                                // While loading from the internet
                                ProgressView()
                                    .frame(height: 180)
                                    .frame(maxWidth: .infinity)
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .cornerRadius(8)
                    } else {
                        // Fallback if there is NO image URL at all
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 180)
                            .cornerRadius(8)
                            .overlay(Text("No Image").foregroundColor(.gray))
                    }
                    
                    
                    
                    Text(listing.title)
                        .font(.headline)
                    
                    Text(listing.price)
                        .foregroundColor(.green)
                        .fontWeight(.semibold)
                    
                    Text(listing.description)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                }
                .padding()
                .background(Color.white)
                .cornerRadius(10)
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            }
            .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        
    //Adding the delete feature ...why do this...
        .task {
                    await listingsVM.fetchListings()
                }
    }
}

#Preview {
    MarketplaceFeedView()
        .environmentObject(ListingsViewModel())
        .environmentObject(AuthViewModel())

}
