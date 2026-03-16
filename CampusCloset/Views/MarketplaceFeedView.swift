import SwiftUI

struct MarketplaceFeedView: View {

    @EnvironmentObject var listingsVM: ListingsViewModel
    

    var body: some View {
        List(listingsVM.listings) { listing in
            NavigationLink(destination: ListingDetailView(listing: listing)) {

                VStack(alignment: .leading, spacing: 8) {
// to be filled with pictures later
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 120)
                        .cornerRadius(8)

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
                .shadow(radius: 2)
            }
        }
    }
}

#Preview {
    MarketplaceFeedView()
        .environmentObject(ListingsViewModel())
}
