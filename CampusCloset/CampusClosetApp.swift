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
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
