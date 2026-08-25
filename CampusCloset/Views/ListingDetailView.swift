//
//  ListingDetailView.swift
//  CampusCloset
//
//  Created by Jun Kuang on 3/14/26.
//

import SwiftUI
import Auth
import Supabase

struct ListingDetailView: View {
    let listing: Listing
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var listingsVM: ListingsViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var showingMessageSheet = false
    @State private var messageText = ""
    @State private var isSending = false
    @State private var alertMessage = ""
    @State private var showingAlert = false
    
    @State private var showingReportAlert = false
    @State private var showingBlockAlert = false
    @State private var showSentOverlay = false
    @State private var showingEditSheet = false


    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                
                // MARK: - NEW Image Carousel
                // Combine new array and legacy single image to check if we have ANY images
                let allImageLinks = listing.imageUrls ?? []
                
                if !allImageLinks.isEmpty {
                    TabView {
                        ForEach(allImageLinks, id: \.self) { urlString in
                            if let url = URL(string: urlString) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image.resizable().scaledToFit().frame(maxWidth: .infinity, maxHeight: 300)
                                            .background(Color.black.opacity(0.05))
                                    case .failure:
                                        Image(systemName: "photo").font(.largeTitle).frame(maxWidth: .infinity, maxHeight: 300).background(Color.gray.opacity(0.1))
                                    case .empty:
                                        ProgressView().frame(maxWidth: .infinity, maxHeight: 300)
                                    @unknown default: EmptyView()
                                    }
                                }
                            }
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: allImageLinks.count > 1 ? .always : .never)) // Only show dots if >1 photo
                    .frame(height: 300)
                    .cornerRadius(12)
                } else {
                    Rectangle().fill(Color.gray.opacity(0.3)).frame(height: 300).cornerRadius(12)
                        .overlay(Text("No Image Available").foregroundColor(.gray))
                }
                
                // MARK: - Listing Details
                Text(listing.title).font(.title).fontWeight(.bold)
                Text(listing.displayPrice).font(.title2).foregroundColor(.green)
                Text(listing.description).font(.body)
                
                HStack {
                    Text(listing.status.displayName)
                        .font(.caption).fontWeight(.bold).padding(.horizontal, 10).padding(.vertical, 5)
                        .background(listing.status == .available ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                        .foregroundColor(listing.status == .available ? .green : .orange).cornerRadius(8)
                    
                    Spacer()
                    
                    if listing.userId == authVM.currentUser?.id {
                        Menu {
                            ForEach(Listing.ListingStatus.allCases, id: \.self) { status in
                                Button(status.displayName) { Task { await listingsVM.updateListingStatus(listing: listing, newStatus: status) } }
                            }
                        } label: { Label("Update Status", systemImage: "pencil.circle").font(.subheadline).foregroundColor(.blue) }
                    }
                }
                .padding(.vertical, 5)
                
                HStack {
                            Image(systemName: "calendar")
                            Text("Posted on \(listing.formattedDate)")
                        }.font(.subheadline).foregroundColor(.secondary)
                        
                // NEW: Clickable Seller Link
                NavigationLink(destination: PublicProfileView(
                    sellerName: listing.profiles?.full_name ?? "Unknown Seller",
                    sellerId: listing.userId
                )) {
                    HStack {
                        Image(systemName: "person.crop.circle")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Seller")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(listing.profiles?.full_name ?? "Unknown Seller")
                                .fontWeight(.medium)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
                
                VStack(spacing: 10) {
                    Button(action: { showingMessageSheet = true }) {
                        Text("Message Seller").fontWeight(.semibold).frame(maxWidth: .infinity).padding()
                            .background(Color.blue).foregroundColor(.white).cornerRadius(10)
                    }

                    if listing.userId == authVM.currentUser?.id {
                        Button {
                            showingEditSheet = true
                        } label: {
                            HStack { Image(systemName: "pencil"); Text("Edit Listing") }
                                .fontWeight(.semibold).frame(maxWidth: .infinity).padding()
                                .background(Color.blue.opacity(0.1)).foregroundColor(.blue).cornerRadius(10)
                        }

                        Button(role: .destructive) {
                            Task { await listingsVM.deleteListing(listing: listing); dismiss() }
                        } label: {
                            HStack { Image(systemName: "trash"); Text("Delete Listing") }
                                .fontWeight(.semibold).frame(maxWidth: .infinity).padding()
                                .background(Color.red.opacity(0.1)).foregroundColor(.red).cornerRadius(10)
                        }
                    }
                }
            }
            .padding()
            .navigationTitle("Listing").navigationBarTitleDisplayMode(.inline)
            
            .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                // Saving your own listing isn't a thing — it's
                                // already on your profile.
                                if listing.userId != authVM.currentUser?.id {
                                    FavoriteButton(listing: listing, size: 18, style: .plain)
                                }
                            }

                            ToolbarItem(placement: .navigationBarTrailing) {
                                // Only show Report/Block menu if it's NOT the user's own listing
                                if listing.userId != authVM.currentUser?.id {
                                    Menu {
                                        Button(role: .destructive) {
                                            Task {
                                                // 1. Safely grab the listing ID
                                                guard let id = listing.id else { return }
                                                
                                                // 2. Call the database function
                                                let success = await listingsVM.reportListing(
                                                    listingId: id,
                                                    reason: "Reported via App"
                                                )
                                                
                                                // 3. If the database save works, show the success alert
                                                if success {
                                                    showingReportAlert = true
                                                } else {
                                                    print("Failed to save report to Supabase.")
                                                }
                                            }
                                        } label: {
                                            Label("Report Item", systemImage: "flag")
                                        }

                                        Button(role: .destructive, action: { showingBlockAlert = true }) {
                                            Label("Block Seller", systemImage: "nosign")
                                        }
                                    } label: {
                                        Image(systemName: "ellipsis.circle")
                                    }
                                }
                            }
                        }
                        .alert("Report Submitted", isPresented: $showingReportAlert) {
                            Button("OK", role: .cancel) { }
                        } message: {
                            Text("Thank you for reporting. Our team will review this item within 24 hours.")
                        }
                        .alert("Block Seller?", isPresented: $showingBlockAlert) {
                            Button("Block", role: .destructive) {
                                Task {
                                    await listingsVM.blockUser(blockedId: listing.userId)
                                    dismiss() // Send user back to feed
                                }
                            }
                            Button("Cancel", role: .cancel) { }
                        } message: {
                            Text("You will no longer see items from this seller.")
                        }
            
            // ... (Message Sheet logic remains exactly the same as your provided code)
            .sheet(isPresented: $showingMessageSheet) {
                NavigationView {
                    VStack {
                        Text("Send a message about \(listing.title)").font(.headline).padding()
                        TextEditor(text: $messageText).frame(height: 150).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.5))).padding()
                        Button(action: { Task { await handleSendMessage() } }) {
                            if isSending { ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)) }
                            else { Text("Send Message") }
                        }
                        .frame(maxWidth: .infinity).padding().background(messageText.isEmpty ? Color.gray : Color.green)
                        .foregroundColor(.white).cornerRadius(10).padding(.horizontal).disabled(messageText.isEmpty || isSending)
                        Spacer()
                    }
                    .navigationTitle("New Message").navigationBarItems(trailing: Button("Cancel") { showingMessageSheet = false })
                }
            }
            .alert(isPresented: $showingAlert) { Alert(title: Text("Status"), message: Text(alertMessage), dismissButton: .default(Text("OK"))) }
            .sheet(isPresented: $showingEditSheet) {
                EditListingView(listing: listing)
                    .environmentObject(listingsVM)
            }
        }
        .overlay {
            if showSentOverlay {
                ZStack {
                    Color.black.opacity(0.45).ignoresSafeArea()
                    VStack(spacing: 18) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.green)
                        Text("Message Sent!")
                            .font(.title2).fontWeight(.bold)
                        Text("Your message was delivered to the seller's email inbox.\nYou'll get a notification here when they reply.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(32)
                    .background(Color.white)
                    .cornerRadius(20)
                    .shadow(radius: 24)
                    .padding(.horizontal, 36)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
    
    private func handleSendMessage() async {
        guard authVM.currentUser != nil else {
            alertMessage = "You must be logged in to send a message."; showingAlert = true; return
        }
        guard let listingId = listing.id else {
            alertMessage = "This listing can't be messaged right now. Please try again."; showingAlert = true; return
        }
        isSending = true
        let success = await listingsVM.sendMessage(listingId: listingId, message: messageText)
        isSending = false
        if success {
            showingMessageSheet = false
            messageText = ""
            withAnimation { showSentOverlay = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation { showSentOverlay = false }
            }
        } else {
            alertMessage = "Failed to send message. Please try again."
            showingAlert = true
        }
    }
}
