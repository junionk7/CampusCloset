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
                                        ZStack {
                                            if let urlString = listing.imageUrl, let url = URL(string: urlString) {
                                                AsyncImage(url: url) { image in
                                                    image.resizable().aspectRatio(1, contentMode: .fill)
                                                } placeholder: {
                                                    Color.gray.opacity(0.3).overlay(ProgressView())
                                                }
                                            } else {
                                                Color.gray.opacity(0.2)
                                                    .overlay(Image(systemName: "bag").foregroundColor(.gray))
                                            }
                                        }
                                        .frame(height: 160)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .shadow(color: .black.opacity(0.1), radius: 3, y: 2)
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
