//
//  ProfileView.swift
//  CampusCloset
//
//  Created by Jun Kuang on 3/14/26.
//
import SwiftUI
import Auth
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var listingsVM: ListingsViewModel

    @State private var isEditing = false
    @State private var editedName = ""
    @State private var editedDorm = ""
    @State private var editedClassYear = ""
    @State private var editedBio = ""
    @State private var showingDeleteAlert = false
    @State private var selectedAvatarItem: PhotosPickerItem? = nil

    var userListings: [Listing] {
        guard let userId = authViewModel.currentUser?.id else { return [] }
        return listingsVM.sellerListings(for: userId)
    }

    var activeCount: Int {
        guard let userId = authViewModel.currentUser?.id else { return 0 }
        return listingsVM.activeCount(for: userId)
    }

    var soldCount: Int {
        guard let userId = authViewModel.currentUser?.id else { return 0 }
        return listingsVM.soldCount(for: userId)
    }

    let columns = [GridItem(.flexible(), spacing: 15), GridItem(.flexible(), spacing: 15)]

    let classYears: [String] = {
        let current = Calendar.current.component(.year, from: Date())
        return (current - 1 ... current + 7).map { "Class of \($0)" }
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 25) {

                    // MARK: - Header Section
                    VStack(spacing: 5) {
                        ZStack(alignment: .bottomTrailing) {
                            // Avatar image
                            if let urlString = authViewModel.avatarUrl, let url = URL(string: urlString) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image.resizable().scaledToFill()
                                            .frame(width: 90, height: 90)
                                            .clipShape(Circle())
                                    default:
                                        Image(systemName: "person.crop.circle.fill")
                                            .resizable()
                                            .frame(width: 90, height: 90)
                                            .foregroundColor(.gray)
                                    }
                                }
                            } else {
                                Image(systemName: "person.crop.circle.fill")
                                    .resizable()
                                    .frame(width: 90, height: 90)
                                    .foregroundColor(.gray)
                            }

                            // Camera button to change avatar
                            PhotosPicker(selection: $selectedAvatarItem, matching: .images) {
                                Image(systemName: "camera.circle.fill")
                                    .symbolRenderingMode(.multicolor)
                                    .font(.system(size: 24))
                                    .background(Color.white.clipShape(Circle()))
                            }
                        }
                        .onChange(of: selectedAvatarItem) { _, newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self),
                                   let image = UIImage(data: data) {
                                    await authViewModel.updateAvatar(image)
                                }
                            }
                        }

                        Text(authViewModel.profileName)
                            .font(.title2)
                            .fontWeight(.bold)

                        Text(authViewModel.currentUser?.email ?? "")
                            .font(.footnote)
                            .foregroundColor(.secondary)

                        Text(authViewModel.joinedDate)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 2)

                        if !authViewModel.classYear.isEmpty {
                            Text(authViewModel.classYear)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        if !authViewModel.dorm.isEmpty {
                            Text(authViewModel.dorm)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        if !authViewModel.bio.isEmpty {
                            Text(authViewModel.bio)
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.top)

                    // MARK: - Stats Row
                    HStack(spacing: 40) {
                        VStack {
                            Text("\(activeCount)")
                                .font(.title3)
                                .fontWeight(.bold)
                            Text("Active")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        VStack {
                            Text("\(soldCount)")
                                .font(.title3)
                                .fontWeight(.bold)
                            Text("Sold")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        VStack {
                            Text("\(listingsVM.favoriteListings.count)")
                                .font(.title3)
                                .fontWeight(.bold)
                            Text("Saved")
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
                        Text("My Posts")
                            .font(.headline)
                            .padding(.horizontal)

                        if userListings.isEmpty {
                            ContentUnavailableView("No listings yet", systemImage: "tag.slash")
                                .padding(.top, 30)
                        } else {
                            LazyVGrid(columns: columns, spacing: 15) {
                                ForEach(userListings) { listing in
                                    NavigationLink(destination: ListingDetailView(listing: listing)) {
                                        ListingGridTile(listing: listing)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    Divider().padding(.horizontal)

                    // MARK: - Saved Items
                    VStack(alignment: .leading) {
                        Text("Saved")
                            .font(.headline)
                            .padding(.horizontal)

                        if listingsVM.favoriteListings.isEmpty {
                            ContentUnavailableView(
                                "Nothing saved yet",
                                systemImage: "heart",
                                description: Text("Tap the heart on any listing to keep it here.")
                            )
                            .padding(.top, 30)
                        } else {
                            LazyVGrid(columns: columns, spacing: 15) {
                                ForEach(listingsVM.favoriteListings) { listing in
                                    NavigationLink(destination: ListingDetailView(listing: listing)) {
                                        ListingGridTile(listing: listing)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.bottom, 30)
            }
            .refreshable {
                await listingsVM.fetchListings(force: true)
                await authViewModel.fetchProfileData()
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            editedName      = authViewModel.profileName
                            editedDorm      = authViewModel.dorm
                            editedClassYear = authViewModel.classYear
                            editedBio       = authViewModel.bio
                            isEditing = true
                        } label: {
                            Label("Edit Profile", systemImage: "pencil")
                        }

                        Button {
                            Task { await authViewModel.signOut() }
                        } label: {
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        }

                        Button(role: .destructive) {
                            showingDeleteAlert = true
                        } label: {
                            Label("Delete Account", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 18))
                    }
                }
            }
            .sheet(isPresented: $isEditing) {
                NavigationStack {
                    Form {
                        Section("Display Name") {
                            TextField("Enter name", text: $editedName)
                        }

                        Section("Class Year") {
                            Picker("Class Year", selection: $editedClassYear) {
                                Text("Not set").tag("")
                                ForEach(classYears, id: \.self) { year in
                                    Text(year).tag(year)
                                }
                            }
                        }

                        Section("Dorm") {
                            TextField("e.g. Smith Hall", text: $editedDorm)
                        }

                        Section("About Me") {
                            TextField("Tell others a bit about yourself...", text: $editedBio, axis: .vertical)
                                .lineLimit(4, reservesSpace: true)
                        }

                        Button("Save Changes") {
                            Task {
                                await authViewModel.updateProfile(
                                    newName: editedName,
                                    dorm: editedDorm,
                                    classYear: editedClassYear,
                                    bio: editedBio
                                )
                                isEditing = false
                            }
                        }
                        .disabled(editedName.isEmpty)
                    }
                    .navigationTitle("Edit Profile")
                    .navigationBarTitleDisplayMode(.inline)
                }
                .presentationDetents([.large])
            }
            .onAppear {
                Task {
                    await authViewModel.fetchProfileData()
                    // Covers landing here before the Marketplace tab has ever
                    // loaded; otherwise the feed's fetch already filled these in.
                    if listingsVM.listings.isEmpty {
                        await listingsVM.fetchListings()
                    }
                }
            }
            .alert("Delete Account?", isPresented: $showingDeleteAlert) {
                Button("Delete", role: .destructive) {
                    Task { await authViewModel.requestAccountDeletion() }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This action is permanent. All your listings will be removed and you will lose access to your account.")
            }
        }
    }
}
