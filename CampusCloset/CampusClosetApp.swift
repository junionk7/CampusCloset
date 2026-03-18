//
//  CampusClosetApp.swift
//  CampusCloset
//
//  Created by Jun Kuang on 3/14/26.
//

import SwiftUI

@main
struct CampusClosetApp: App {
    
    // 1. Keep your original listings view model
    @StateObject var listingsVM = ListingsViewModel()
    
    // 2. Add the new auth view model
    @StateObject var authViewModel = AuthViewModel()
    
    var body: some Scene {
        WindowGroup {
            // 3. Logic: If logged in, show the app. If not, show Login.
            if authViewModel.isAuthenticated {
                ContentView()
                    .environmentObject(authViewModel) // Pass auth to the whole app
                    .environmentObject(listingsVM)    // Pass listings to the whole app
            } else {
                AuthView()
                    .environmentObject(authViewModel)
            }
        }
    }
}
