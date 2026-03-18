//
//  AuthViewModel.swift
//  CampusCloset
//
//  Created by Jun Kuang on 3/18/26.
//

import Foundation
import Supabase
import SwiftUI
import Combine

@MainActor
class AuthViewModel: ObservableObject {
    // MARK: - State
    @Published var currentUser: User?
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    init() {
        Task {
            await observeAuthState()
        }
    }
    
    // MARK: - Auth Listener
    private func observeAuthState() async {
        // This keeps the app in sync with Supabase Auth (even after app restarts)
        for await (event, session) in supabase.auth.authStateChanges {
            print("Auth Event: \(event)")
            self.currentUser = session?.user
            self.isAuthenticated = (session?.user != nil)
        }
    }
    
    // MARK: - Actions
    
    func signUp(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Simple sign up with just email/password
            try await supabase.auth.signUp(email: email, password: password)
            // Note: If 'Confirm Email' is ON in Supabase, user stays logged out
            // until they click the link in their inbox.
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await supabase.auth.signIn(email: email, password: password)
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    func signOut() async {
        do {
            try await supabase.auth.signOut()
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
}
