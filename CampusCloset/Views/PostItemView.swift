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
    @State private var selectedCategory: Listing.ListingCategory = .other // Default category
    
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var isPosting = false

    var body: some View {
        NavigationStack {
            Form {
                // Info Section
                Section(header: Text("Item Information")) {
                    TextField("Item Title", text: $title)
                    TextField("Price (e.g. $15 or Free)", text: $price)
                        .keyboardType(.default) // Changed from decimalPad so users can type "Free"
                    
                    // NEW: Category Picker
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(Listing.ListingCategory.allCases, id: \.self) { cat in
                            Text(cat.displayName).tag(cat)
                        }
                    }
                    
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...5)
                }
                
                // Photos Section
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
                
                // Button
                Section {
                    Button(action: postListing) {
                        if isPosting {
                            ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Post Listing")
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .foregroundColor(.white)
                    .listRowBackground(title.isEmpty || isPosting ? Color.gray : Color.blue)
                    .disabled(title.isEmpty || authViewModel.currentUser == nil || isPosting)
                }
            }
            .navigationTitle("Post Item")
            .onChange(of: selectedItem) { oldValue, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        selectedImage = image
                    }
                }
            }
        }
    }

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
                imageUrl: link,
                category: selectedCategory // Now passes the selected category to the view model
            )
            
            // Clear fields after successful post
            title = ""
            price = ""
            description = ""
            selectedCategory = .other
            selectedImage = nil
            selectedItem = nil
            isPosting = false
        }
    }
}
