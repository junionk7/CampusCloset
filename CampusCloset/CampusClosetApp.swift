//
//  CampusClosetApp.swift
//  CampusCloset
//
//  Created by Jun Kuang on 3/14/26.
//

import SwiftUI

@main
struct CampusClosetApp: App {
    
    @StateObject var listingsVM = ListingsViewModel()
    @StateObject var authViewModel = AuthViewModel()
    @StateObject var notificationsVM = NotificationsViewModel()

    init() {
        // Has to happen before the first image request, so AsyncImage can
        // actually keep what it downloads. See ImageCache for why.
        ImageCache.configure()
    }

    var body: some Scene {
        WindowGroup {
            // 3. Logic: If logged in, show the app. If not, show Login.
            if authViewModel.isAuthenticated {
                ContentView()
                    .environmentObject(authViewModel)
                    .environmentObject(listingsVM)
                    .environmentObject(notificationsVM)
                    .preferredColorScheme(.light)
            } else {
                AuthView()
                    .environmentObject(authViewModel)
                    .preferredColorScheme(.light)
            }
        }
    }
}
