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
                Text(listing.price).font(.title2).foregroundColor(.green)
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
                
                Spacer()
                
                Button(action: { showingMessageSheet = true }) {
                    Text("Message Seller").fontWeight(.semibold).frame(maxWidth: .infinity).padding()
                        .background(Color.blue).foregroundColor(.white).cornerRadius(10)
                }
                
                if listing.userId == authVM.currentUser?.id {
                    Button(role: .destructive) {
                        Task { await listingsVM.deleteListing(listing: listing); dismiss() }
                    } label: {
                        HStack { Image(systemName: "trash"); Text("Delete Listing") }
                            .fontWeight(.semibold).frame(maxWidth: .infinity).padding()
                            .background(Color.red.opacity(0.1)).foregroundColor(.red).cornerRadius(10)
                    }.padding(.top, 10)
                }
            }
            .padding()
            .navigationTitle("Listing").navigationBarTitleDisplayMode(.inline)
            
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
        }
    }
    
    private func handleSendMessage() async {
        guard let buyerEmail = authVM.currentUser?.email else {
            alertMessage = "You must be logged in to send a message."; showingAlert = true; return
        }
        isSending = true
        let success = await listingsVM.sendMessage(sellerId: listing.userId, itemTitle: listing.title, buyerEmail: buyerEmail, message: messageText)
        isSending = false
        if success { showingMessageSheet = false; messageText = ""; alertMessage = "Message sent successfully!" }
        else { alertMessage = "Failed to send message. Please try again." }
        showingAlert = true
    }
}
