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
    
    // New states for the email confirmation flow
    @Published var showConfirmationMessage: Bool = false
    @Published var canResendEmail: Bool = true
    @Published var resendCountdown: Int = 0
    
    init() {
        Task {
            await observeAuthState()
        }
    }
    
    // MARK: - Auth Listener
    private func observeAuthState() async {
        for await (event, session) in supabase.auth.authStateChanges {
            print("Auth Event: \(event)")
            self.currentUser = session?.user
            self.isAuthenticated = (session?.user != nil)
            
            // Auto-hide the confirmation message if they confirm and log in
            if self.isAuthenticated {
                self.showConfirmationMessage = false
            }
        }
    }
    
    // MARK: - Actions
    
    func signUp(email: String, password: String, confirmPassword: String) async {
        guard password == confirmPassword else {
            self.errorMessage = "Passwords do not match."
            return
        }
        
        guard password.count >= 6 else {
            self.errorMessage = "Password must be at least 6 characters."
            return
        }

        isLoading = true
        errorMessage = nil
        
        do {
            try await supabase.auth.signUp(email: email, password: password)
            // Successfully triggered the signup, now show the email instruction screen
            self.showConfirmationMessage = true
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
    
    func resendConfirmationEmail(email: String) async {
        guard canResendEmail else { return }
        
        do {
            try await supabase.auth.resend(email: email, type: .signup)
            startResendTimer()
        } catch {
            self.errorMessage = "Could not resend: \(error.localizedDescription)"
        }
    }
    
    private func startResendTimer() {
            canResendEmail = false
            resendCountdown = 30
            
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
                // Use a Task to jump back to the @MainActor to update published properties
                Task { @MainActor in
                    guard let self = self else {
                        timer.invalidate()
                        return
                    }
                    
                    if self.resendCountdown > 0 {
                        self.resendCountdown -= 1
                    } else {
                        self.canResendEmail = true
                        timer.invalidate()
                    }
                }
            }
        }
    
    func signOut() async {
        do {
            try await supabase.auth.signOut()
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
}
