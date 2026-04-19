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
    @State private var selectedCategory: Listing.ListingCategory = .other
    
    // NEW: Array states for multiple selection
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var isPosting = false

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Item Information")) {
                    TextField("Item Title", text: $title)
                    TextField("Price (e.g. $15 or Free)", text: $price).keyboardType(.default)
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(Listing.ListingCategory.allCases, id: \.self) { cat in Text(cat.displayName).tag(cat) }
                    }
                    TextField("Description", text: $description, axis: .vertical).lineLimit(3...5)
                }
                
                Section(header: Text("Photos (Up to 6)")) {
                    // NEW: Allow up to 6 images
                    PhotosPicker(selection: $selectedItems, maxSelectionCount: 6, matching: .images) {
                        Label(selectedImages.isEmpty ? "Select Photos" : "Add/Edit Photos", systemImage: "photo.on.rectangle")
                    }
                    
                    // NEW: Horizontal gallery preview
                    if !selectedImages.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(0..<selectedImages.count, id: \.self) { index in
                                    Image(uiImage: selectedImages[index])
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .clipped()
                                        .cornerRadius(8)
                                }
                            }
                            .padding(.vertical, 5)
                        }
                    }
                }
                
                Section {
                    Button(action: postListing) {
                        if isPosting {
                            ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Post Listing").fontWeight(.bold).frame(maxWidth: .infinity)
                        }
                    }
                    .foregroundColor(.white)
                    .listRowBackground(title.isEmpty || isPosting ? Color.gray : Color.blue)
                    .disabled(title.isEmpty || authViewModel.currentUser == nil || isPosting)
                }
            }
            .navigationTitle("Post Item")
            // NEW: Load all selected images into the array
            .onChange(of: selectedItems) { oldValue, newValue in
                Task {
                    selectedImages.removeAll()
                    for item in newValue {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            selectedImages.append(image)
                        }
                    }
                }
            }
        }
    }

    private func postListing() {
        guard let userId = authViewModel.currentUser?.id else { return }
        isPosting = true
        
        Task {
            // Upload all images and get the array of links back
            let links = await listingsVM.uploadImages(images: selectedImages)
            
            await listingsVM.addListing(
                title: title,
                price: price,
                description: description,
                userId: userId,
                imageUrls: links, // Pass array
                category: selectedCategory
            )
            
            title = ""
            price = ""
            description = ""
            selectedCategory = .other
            selectedImages.removeAll()
            selectedItems.removeAll()
            isPosting = false
        }
    }
}
