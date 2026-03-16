//
//  Listing.swift
//  CampusCloset
//
//  Created by Jun Kuang on 3/14/26.
//
import Foundation

//data structure of a listing
struct Listing: Identifiable {
    let id = UUID()
    let title: String
    let price: String
    let description: String
}
