//
//  PostItemView.swift
//  CampusCloset
//
//  Created by Jun Kuang on 3/14/26.
//


import SwiftUI

struct PostItemView: View {

    // Access the shared listings manager
    @EnvironmentObject var listingsVM: ListingsViewModel

    // Form inputs
    @State private var title = ""
    @State private var price = ""
    @State private var description = ""

    var body: some View {

        NavigationStack {

            Form {

                Section(header: Text("Item Information")) {

                    TextField("Item Title", text: $title)

                    TextField("Price", text: $price)

                    TextField("Description", text: $description)

                }

                Section {

                    Button("Post Listing") {
                        Task {
                            await listingsVM.addListing(
                                title: title,
                                price: price,
                                description: description
                            )

                            // Clear the form
                            title = ""
                            price = ""
                            description = ""
                        }
                    }

                }

            }
            .navigationTitle("Post Item")
        }
    }
}

#Preview {
    PostItemView()
    //Don't fully understand what this does
        .environmentObject(ListingsViewModel())
}
