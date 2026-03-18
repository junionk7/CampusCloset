//
//  ContentView.swift
//  CampusCloset
//
//  Created by Jun Kuang on 3/14/26.
//

import SwiftUI

struct ContentView: View {
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

            MessagesView()
                .tabItem {
                    Label("Messages", systemImage: "message")
                }

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
}
