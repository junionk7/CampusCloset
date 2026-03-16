//
//  MarketplaceView.swift
//  CampusCloset
//
//  Created by Jun Kuang on 3/14/26.
//
import SwiftUI

struct MarketplaceView: View {

    var body: some View {

        NavigationStack {

            MarketplaceFeedView()
                .navigationTitle("Marketplace")

        }

    }
}

#Preview {
    MarketplaceView()
}

