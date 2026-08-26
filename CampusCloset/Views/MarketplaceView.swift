//
//  MarketplaceView.swift
//  CampusCloset
//
//  Created by Jun Kuang on 3/14/26.
//
import SwiftUI

struct MarketplaceView: View {
    @EnvironmentObject var listingsVM: ListingsViewModel
    @EnvironmentObject var notificationsVM: NotificationsViewModel

    var body: some View {
        NavigationStack {
            MarketplaceFeedView()
                .navigationTitle("Marketplace")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        NavigationLink(destination: NotificationsView()) {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "bell")
                                    .font(.system(size: 18))
                                if notificationsVM.unreadCount > 0 {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 9, height: 9)
                                        .offset(x: 5, y: -4)
                                }
                            }
                        }
                    }
                }
                // No fetch here — MarketplaceFeedView's .task owns loading the
                // feed. Having both meant two full-table reads per visit.
        }
    }
}

#Preview {
    MarketplaceView()
        .environmentObject(ListingsViewModel())
        .environmentObject(NotificationsViewModel())
}
