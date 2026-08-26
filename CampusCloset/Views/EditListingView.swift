//
//  EditListingView.swift
//  CampusCloset
//

import SwiftUI
import PhotosUI

struct EditListingView: View {
    let listing: Listing
    @EnvironmentObject var listingsVM: ListingsViewModel
    @Environment(\.dismiss) var dismiss

    @State private var title: String
    @State private var price: String
    @State private var isFree: Bool
    @State private var description: String
    @State private var selectedCategory: Listing.ListingCategory

    /// A photo already on the listing. The full-size URL and its thumbnail travel
    /// together so removing one from the strip can never leave the two arrays
    /// misaligned on save.
    private struct ExistingPhoto: Identifiable, Equatable {
        let imageUrl: String
        let thumbnailUrl: String
        var id: String { imageUrl }
    }

    @State private var existingPhotos: [ExistingPhoto]

    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var newImages: [UIImage] = []
    @State private var isSaving = false

    init(listing: Listing) {
        self.listing = listing
        _title = State(initialValue: listing.title)
        let free = listing.price.lowercased() == "free"
        _isFree = State(initialValue: free)
        _price = State(initialValue: free ? "" : listing.price)
        _description = State(initialValue: listing.description)
        _selectedCategory = State(initialValue: listing.category)

        let images = listing.imageUrls ?? []
        _existingPhotos = State(initialValue: images.enumerated().map { index, imageUrl in
            ExistingPhoto(
                imageUrl: imageUrl,
                // Falls back to the full-size URL on listings posted before
                // thumbnails existed.
                thumbnailUrl: listing.thumbnailUrl(at: index) ?? imageUrl
            )
        })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Item Information")) {
                    TextField("Item Title", text: $title)
                    Toggle(isOn: $isFree) {
                        Label("Free", systemImage: "gift")
                    }
                    .tint(.green)
                    if !isFree {
                        TextField("Price", text: $price)
                            .keyboardType(.decimalPad)
                            .onChange(of: price) { _, newValue in
                                price = newValue.filter { $0.isNumber || $0 == "." }
                            }
                    }
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(Listing.ListingCategory.allCases, id: \.self) { cat in
                            Text(cat.displayName).tag(cat)
                        }
                    }
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...5)
                }

                Section(header: Text("Current Photos")) {
                    if existingPhotos.isEmpty {
                        Text("No photos").foregroundColor(.secondary)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(existingPhotos) { photo in
                                    ZStack(alignment: .topTrailing) {
                                        // 100pt strip — thumbnail is plenty.
                                        if let url = URL(string: photo.thumbnailUrl) {
                                            AsyncImage(url: url) { phase in
                                                switch phase {
                                                case .success(let image):
                                                    image.resizable().scaledToFill()
                                                        .frame(width: 100, height: 100).clipped().cornerRadius(8)
                                                default:
                                                    Rectangle().fill(Color.gray.opacity(0.3))
                                                        .frame(width: 100, height: 100).cornerRadius(8)
                                                }
                                            }
                                        }
                                        Button {
                                            existingPhotos.removeAll { $0.imageUrl == photo.imageUrl }
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.red)
                                                .background(Color.white.clipShape(Circle()))
                                        }
                                        .padding(4)
                                    }
                                }
                            }
                            .padding(.vertical, 5)
                        }
                    }
                }

                Section(header: Text("Add More Photos")) {
                    PhotosPicker(selection: $selectedItems, maxSelectionCount: max(1, 6 - existingPhotos.count), matching: .images) {
                        Label("Select Photos", systemImage: "photo.on.rectangle")
                    }
                    if !newImages.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(0..<newImages.count, id: \.self) { index in
                                    Image(uiImage: newImages[index])
                                        .resizable().scaledToFill()
                                        .frame(width: 100, height: 100).clipped().cornerRadius(8)
                                }
                            }
                            .padding(.vertical, 5)
                        }
                    }
                }

                Section {
                    Button(action: saveChanges) {
                        if isSaving {
                            ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Save Changes").fontWeight(.bold).frame(maxWidth: .infinity)
                        }
                    }
                    .foregroundColor(.white)
                    .listRowBackground(title.isEmpty || isSaving ? Color.gray : Color.blue)
                    .disabled(title.isEmpty || isSaving)
                }
            }
            .navigationTitle("Edit Listing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onChange(of: selectedItems) { _, newValue in
                Task {
                    newImages.removeAll()
                    for item in newValue {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            newImages.append(image)
                        }
                    }
                }
            }
        }
    }

    private func saveChanges() {
        isSaving = true
        Task {
            let uploaded = await listingsVM.uploadImages(images: newImages)
            await listingsVM.updateListing(
                listing: listing,
                title: title,
                price: isFree ? "Free" : price,
                description: description,
                category: selectedCategory,
                imageUrls: existingPhotos.map(\.imageUrl) + uploaded.imageUrls,
                thumbnailUrls: existingPhotos.map(\.thumbnailUrl) + uploaded.thumbnailUrls
            )
            isSaving = false
            dismiss()
        }
    }
}
