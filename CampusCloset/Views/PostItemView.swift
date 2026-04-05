//
//  PostItemView.swift
//  CampusCloset
//
//  Created by Jun Kuang on 3/14/26.
//


import SwiftUI
import Auth
import PhotosUI

struct PostItemView: View {
    @EnvironmentObject var listingsVM: ListingsViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var title = ""
    @State private var price = ""
    @State private var description = ""
    
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var isPosting = false

    var body: some View {
        NavigationStack {
            Form {
                //menus
                Section(header: Text("Item Information")) {
                    TextField("Item Title", text: $title)
                    TextField("Price", text: $price)
                        .keyboardType(.decimalPad)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...5)
                }
                //Photos Section
                Section(header: Text("Photo")) {
                                PhotosPicker(selection: $selectedItem, matching: .images) {
                                    if let selectedImage {
                                        Image(uiImage: selectedImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(height: 200)
                                            .clipped()
                                            .cornerRadius(10)
                                    } else {
                                        Label("Select a Photo", systemImage: "photo.on.rectangle")
                                            .frame(maxWidth: .infinity, minHeight: 150)
                                            .background(Color(.systemGray6))
                                            .cornerRadius(10)
                                    }
                                }
                            }
                //BUtton
                Section {
                    Button(action: postListing) {
                        Text("Post Listing")
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                    }
                    .foregroundColor(.white)
                    // Disable button if title is empty, no image is picked, or currently posting
                    .listRowBackground(title.isEmpty ? Color.gray : Color.blue)
                    .disabled(title.isEmpty || authViewModel.currentUser == nil)
                    
                }
            }
            
            
            .navigationTitle("Post Item")
            
            .onChange(of: selectedItem) { oldValue, newValue in
                Task {
                    // We use newValue here because that is the item the user just picked
                    if let data = try? await newValue?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        selectedImage = image
                    }
                }
            }
            
        }
    }

    // Logic moved to a function to keep 'body' clean
    private func postListing() {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        isPosting = true
        
        Task {
            var link: String? = nil
                        if let image = selectedImage {
                            link = await listingsVM.uploadImage(image)
                        }
            
            await listingsVM.addListing(
                title: title,
                price: price,
                description: description,
                userId: userId,
                imageUrl: link
            )
            
            // Clear fields after successful post
            title = ""
            price = ""
            description = ""
            selectedImage = nil
            selectedItem = nil
            isPosting = false
        }
    }
}
