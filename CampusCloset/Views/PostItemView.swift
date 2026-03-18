//
//  PostItemView.swift
//  CampusCloset
//
//  Created by Jun Kuang on 3/14/26.
//


import SwiftUI
import Supabase
import Auth

struct PostItemView: View {
    @EnvironmentObject var listingsVM: ListingsViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var title = ""
    @State private var price = ""
    @State private var description = ""

    var body: some View {
        NavigationStack {
            VStack {
                Form {
                    Section(header: Text("Item Information")) {
                        TextField("Item Title", text: $title)
                        TextField("Price", text: $price)
                        TextField("Description", text: $description)
                    }
                }
                
                // MOVE BUTTON HERE - Outside the Form
                Button(action: {
                    print("🔘 BUTTON CLICKED")
                    
                    if let userId = authViewModel.currentUser?.id {
                        print("✅ Proceeding with User ID: \(userId)")
                        Task {
                            await listingsVM.addListing(
                                title: title,
                                price: price,
                                description: description,
                                userId: userId
                            )
                            title = ""; price = ""; description = ""
                        }
                    } else {
                        print("❌ ERROR: No User ID found. You need to Sign Out and Sign In.")
                    }
                }) {
                    Text("Post Listing")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(authViewModel.currentUser == nil ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.horizontal)
                }
                .disabled(authViewModel.currentUser == nil)
                
                Spacer().frame(height: 20)
            }
            .navigationTitle("Post Item")
        }
    }
}
#Preview {
    PostItemView()
        .environmentObject(ListingsViewModel())
        .environmentObject(AuthViewModel())
}
