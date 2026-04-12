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

// Helper structs for safe database reading/writing
struct ProfileData: Codable {
    let full_name: String?
    let joined_at: String?
}

struct ProfileInsert: Codable {
    let id: UUID
    let full_name: String
}

@MainActor
class AuthViewModel: ObservableObject {
    // MARK: - State
    @Published var currentUser: User?
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // Email confirmation flow
    @Published var showConfirmationMessage: Bool = false
    @Published var canResendEmail: Bool = true
    @Published var resendCountdown: Int = 0
    
    // Profile Data
    @Published var profileName: String = "Loading..."
    @Published var joinedDate: String = ""
    
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
            
            if self.isAuthenticated {
                self.showConfirmationMessage = false
                // Small fix: wait a split second for the session to settle before fetching
                Task {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    await fetchProfileData()
                }
            }
        }
    }
    
    // MARK: - Actions
    func signUp(email: String, password: String, confirmPassword: String, firstName: String, lastName: String) async {
        guard password == confirmPassword else {
            self.errorMessage = "Passwords do not match."
            return
        }
        
        guard password.count >= 6 else {
            self.errorMessage = "Password must be at least 6 characters."
            return
        }
        
        guard !firstName.isEmpty && !lastName.isEmpty else {
            self.errorMessage = "First and last name are required."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let authResponse = try await supabase.auth.signUp(email: email, password: password)
            let userId = authResponse.user.id
            let combinedName = "\(firstName) \(lastName)"
            
            let newProfile = ProfileInsert(id: userId, full_name: combinedName)
            try await supabase.from("profiles").insert(newProfile).execute() // Using 'try?' so it doesn't crash the whole sign-up if the profile row fails
            
            
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
    
    // MARK: - Profile Management
    
    // FIXED: Added the missing updateProfile function to resolve ProfileView errors
    func updateProfile(newName: String) async {
        guard let userId = currentUser?.id else { return }
        isLoading = true
        
        do {
            try await supabase
                .from("profiles")
                .update(["full_name": newName])
                .eq("id", value: userId)
                .execute()
            
            // Immediately update the UI
            self.profileName = newName
        } catch {
            self.errorMessage = "Failed to update: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    func fetchProfileData() async {
        guard let userId = currentUser?.id else { return }
        
        do {
            let profile: ProfileData = try await supabase
                .from("profiles")
                .select("full_name, joined_at")
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            
            self.profileName = profile.full_name ?? "Unknown"
            
            if let dateString = profile.joined_at {
                self.joinedDate = formatJoinDate(dateString)
            }
        } catch {
            print("Profile fetch error: \(error)")
            self.profileName = "Student"
        }
    }
    
    private func formatJoinDate(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        var date = formatter.date(from: isoString)
        if date == nil {
            formatter.formatOptions = [.withInternetDateTime]
            date = formatter.date(from: isoString)
        }
        
        guard let validDate = date else { return "Recently joined" }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "'Joined' MMM yyyy"
        return displayFormatter.string(from: validDate)
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
