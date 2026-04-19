//
//  ProfileView.swift
//  CampusCloset
//
//  Created by Jun Kuang on 3/14/26.
//
import SwiftUI
import Auth

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var listingsVM: ListingsViewModel
    
    @State private var isEditing = false
    @State private var editedName = ""
    
    var userListings: [Listing] {
        listingsVM.listings.filter { $0.userId == authViewModel.currentUser?.id }
    }
    
    let columns = [GridItem(.flexible(), spacing: 15), GridItem(.flexible(), spacing: 15)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 25) {
                    
                    // MARK: - Header Section
                    VStack(spacing: 5) {
                        ZStack(alignment: .bottomTrailing) {
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .frame(width: 90, height: 90)
                                .foregroundColor(.gray)
                            
                            Button {
                                editedName = authViewModel.profileName
                                isEditing = true
                            } label: {
                                Image(systemName: "pencil.circle.fill")
                                    .symbolRenderingMode(.multicolor)
                                    .font(.system(size: 24))
                                    .background(Color.white.clipShape(Circle()))
                            }
                        }
                        
                        Text(authViewModel.profileName)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        // Email listed below the name
                        Text(authViewModel.currentUser?.email ?? "")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        
                        Text(authViewModel.joinedDate)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 2)
                    }
                    .padding(.top)
                    
                    // MARK: - Stats Row
                    HStack(spacing: 60) {
                        VStack {
                            Text("\(userListings.count)")
                                .font(.title3)
                                .fontWeight(.bold)
                            Text("Listings")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack {
                            Text("0")
                                .font(.title3)
                                .fontWeight(.bold)
                            Text("Sold")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 15)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(15)
                    .padding(.horizontal)
                    
                    Divider().padding(.horizontal)
                    
                    // MARK: - Post Gallery
                    VStack(alignment: .leading) {
                        Text("Active Posts")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        if userListings.isEmpty {
                            ContentUnavailableView("No listings yet", systemImage: "tag.slash")
                                .padding(.top, 30)
                        } else {
                            LazyVGrid(columns: columns, spacing: 15) {
                                ForEach(userListings) { listing in
                                    NavigationLink(destination: ListingDetailView(listing: listing)) {
                                        VStack(alignment: .leading) {
                                            // UPDATED: Use displayImageUrl helper instead of imageUrl
                                            if let urlString = listing.displayImageUrl, let url = URL(string: urlString) {
                                                AsyncImage(url: url) { phase in
                                                    switch phase {
                                                    case .success(let image):
                                                        image
                                                            .resizable()
                                                            .scaledToFill()
                                                            .frame(height: 120)
                                                            .clipped()
                                                            .cornerRadius(10)
                                                    case .failure, .empty:
                                                        RoundedRectangle(cornerRadius: 10)
                                                            .fill(Color.gray.opacity(0.2))
                                                            .frame(height: 120)
                                                            .overlay(Image(systemName: "photo").foregroundColor(.gray))
                                                    @unknown default:
                                                        EmptyView()
                                                    }
                                                }
                                            } else {
                                                // Fallback for listings with no images
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(Color.gray.opacity(0.2))
                                                    .frame(height: 120)
                                                    .overlay(Image(systemName: "photo").foregroundColor(.gray))
                                            }
                                            
                                            Text(listing.title)
                                                .font(.caption)
                                                .fontWeight(.bold)
                                                .lineLimit(1)
                                            
                                            Text(listing.price)
                                                .font(.caption2)
                                                .foregroundColor(.green)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.bottom, 30)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(role: .destructive) {
                        Task { await authViewModel.signOut() }
                    } label: {
                        Text("Sign Out").foregroundColor(.red)
                    }
                }
            }
            .sheet(isPresented: $isEditing) {
                NavigationStack {
                    Form {
                        Section("Display Name") {
                            TextField("Enter name", text: $editedName)
                        }
                        Button("Save Changes") {
                            Task {
                                await authViewModel.updateProfile(newName: editedName)
                                isEditing = false
                            }
                        }
                        .disabled(editedName.isEmpty)
                    }
                    .navigationTitle("Edit Profile")
                }
                .presentationDetents([.medium])
            }
            .onAppear {
                Task { await authViewModel.fetchProfileData() }
            }
        }
    }
}
