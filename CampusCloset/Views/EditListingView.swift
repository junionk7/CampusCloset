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
    @State private var existingImageUrls: [String]

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
        _existingImageUrls = State(initialValue: listing.imageUrls ?? [])
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
                    if existingImageUrls.isEmpty {
                        Text("No photos").foregroundColor(.secondary)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(existingImageUrls, id: \.self) { urlString in
                                    ZStack(alignment: .topTrailing) {
                                        if let url = URL(string: urlString) {
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
                                            existingImageUrls.removeAll { $0 == urlString }
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
                    PhotosPicker(selection: $selectedItems, maxSelectionCount: max(1, 6 - existingImageUrls.count), matching: .images) {
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
            let uploadedUrls = await listingsVM.uploadImages(images: newImages)
            let finalUrls = existingImageUrls + uploadedUrls
            await listingsVM.updateListing(
                listing: listing,
                title: title,
                price: isFree ? "Free" : price,
                description: description,
                category: selectedCategory,
                imageUrls: finalUrls
            )
            isSaving = false
            dismiss()
        }
    }
}
