//
//  ListingsViewModel.swift
//  CampusCloset
//
//  Created by Jun Kuang on 3/15/26.
//

import Foundation
import SwiftUI
import Combine

class ListingsViewModel: ObservableObject {

    @Published var listings: [Listing] = [
        Listing(title: "Mini Fridge", price: "$40", description: "Used for one year."),
        Listing(title: "Desk Lamp", price: "$5", description: "Works perfectly."),
        Listing(title: "Fan", price: "Free", description: "Leaving campus soon.")
    ]

    func addListing(_ listing: Listing) {
        listings.append(listing)
    }
}
