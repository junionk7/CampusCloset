//
//  ProfileView.swift
//  CampusCloset
//
//  Created by Jun Kuang on 3/14/26.
//
import SwiftUI
import Supabase

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            List {
                Section("Account Info") {
                    Text("Email: \(authViewModel.currentUser?.email ?? "Unknown")")
                    Text("User ID: \(authViewModel.currentUser?.id.uuidString ?? "No ID found")")
                }
                
                Section {
                    Button(role: .destructive) {
                        Task {
                            await authViewModel.signOut()
                        }
                    } label: {
                        Text("Sign Out")
                    }
                }
            }
            .navigationTitle("Profile")
        }
    }
}
