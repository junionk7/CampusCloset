//
//  ListingDetailView.swift
//  CampusCloset
//
//  Created by Jun Kuang on 3/14/26.
//

import SwiftUI
import Auth

struct ListingDetailView: View {
    let listing: Listing
    
    // Bring in ViewModels to access auth and network functions
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var listingsVM: ListingsViewModel
    
    @Environment(\.dismiss) var dismiss
    
    // State variables for the message sheet
    @State private var showingMessageSheet = false
    @State private var messageText = ""
    @State private var isSending = false
    @State private var alertMessage = ""
    @State private var showingAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                
                if let urlString = listing.imageUrl, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFit().frame(maxWidth: .infinity).frame(height: 300)
                                .background(Color.black.opacity(0.05)).cornerRadius(12)
                        case .failure:
                            Image(systemName: "photo").font(.largeTitle).frame(maxWidth: .infinity)
                                .frame(height: 300).background(Color.gray.opacity(0.1)).cornerRadius(12)
                        case .empty:
                            ProgressView().frame(maxWidth: .infinity).frame(height: 300)
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    Rectangle().fill(Color.gray.opacity(0.3)).frame(height: 300).cornerRadius(12)
                        .overlay(Text("No Image Available").foregroundColor(.gray))
                }
                
                Text(listing.title).font(.title).fontWeight(.bold)
                Text(listing.price).font(.title2).foregroundColor(.green)
                Text(listing.description).font(.body)
                
                //To add the date
                HStack {
                    Image(systemName: "calendar")
                    Text("Posted on \(listing.formattedDate)")
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
                
                Spacer()
                
                // Trigger the message sheet
                Button(action: {
                    showingMessageSheet = true
                }) {
                    Text("Message Seller")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                //Only show if it's the users post
            }
            
            
            .padding()
            .navigationTitle("Listing")
            .navigationBarTitleDisplayMode(.inline)
            
            // The messaging pop-up sheet
            .sheet(isPresented: $showingMessageSheet) {
                NavigationView {
                    VStack {
                        Text("Send a message about \(listing.title)")
                            .font(.headline)
                            .padding()
                        
                        TextEditor(text: $messageText)
                            .frame(height: 150)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.5)))
                            .padding()
                        
                        Button(action: {
                            Task {
                                await handleSendMessage()
                            }
                        }) {
                            if isSending {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Send Message")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(messageText.isEmpty ? Color.gray : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.horizontal)
                        .disabled(messageText.isEmpty || isSending)
                        
                        Spacer()
                    }
                    .navigationTitle("New Message")
                    .navigationBarItems(trailing: Button("Cancel") {
                        showingMessageSheet = false
                    })
                }
            }
            // Alert for Success/Failure
            .alert(isPresented: $showingAlert) {
                Alert(title: Text("Status"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        }
    }
    
    // Extracted logic for clarity
    private func handleSendMessage() async {
        guard let buyerEmail = authVM.currentUser?.email else {
            alertMessage = "You must be logged in to send a message."
            showingAlert = true
            return
        }
        
        isSending = true
        
        let success = await listingsVM.sendMessage(
            sellerId: listing.userId,
            itemTitle: listing.title,
            buyerEmail: buyerEmail,
            message: messageText
        )
        
        isSending = false
        
        if success {
            showingMessageSheet = false
            messageText = "" // Clear the box
            alertMessage = "Message sent successfully!"
        } else {
            alertMessage = "Failed to send message. Please try again."
        }
        showingAlert = true
    }
}
