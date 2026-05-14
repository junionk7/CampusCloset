//
//  ContentView.swift
//  CampusCloset
//
//  Created by Jun Kuang on 3/14/26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var notificationsVM: NotificationsViewModel

    var body: some View {
        TabView {

            MarketplaceView()
                .tabItem {
                    Label("Marketplace", systemImage: "house")
                }

            SearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }

            PostItemView()
                .tabItem {
                    Label("Post", systemImage: "plus.circle")
                }

            NotificationsView()
                .tabItem {
                    Label("Notifications", systemImage: "bell")
                }
                .badge(notificationsVM.unreadCount)

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person")
                }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(ListingsViewModel())
        .environmentObject(AuthViewModel())
        .environmentObject(NotificationsViewModel())
}
