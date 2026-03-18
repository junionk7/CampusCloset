//
//  MarketplaceView.swift
//  CampusCloset
//
//  Created by Jun Kuang on 3/14/26.
//
import SwiftUI

struct MarketplaceView: View {
    // 1. You need to access the ViewModel here to call the fetch function
    @EnvironmentObject var listingsVM: ListingsViewModel

    var body: some View {
        NavigationStack {
            MarketplaceFeedView()
                .navigationTitle("Marketplace")
                // 2. Add this modifier here
                .onAppear {
                    Task {
                        await listingsVM.fetchListings()
                    }
                }
        }
    }
}

// 3. Update your preview so it doesn't crash
#Preview {
    MarketplaceView()
        .environmentObject(ListingsViewModel())
}
