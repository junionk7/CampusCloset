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
    let dorm: String?
    let class_year: String?
    let bio: String?
    let avatar_url: String?
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
    @Published var dorm: String = ""
    @Published var classYear: String = ""
    @Published var bio: String = ""
    @Published var avatarUrl: String? = nil
    
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
    func updateProfile(newName: String, dorm: String, classYear: String, bio: String) async {
        guard let userId = currentUser?.id else { return }
        isLoading = true

        do {
            try await supabase
                .from("profiles")
                .update([
                    "full_name":  newName,
                    "dorm":       dorm,
                    "class_year": classYear,
                    "bio":        bio
                ])
                .eq("id", value: userId)
                .execute()

            self.profileName = newName
            self.dorm        = dorm
            self.classYear   = classYear
            self.bio         = bio
        } catch {
            self.errorMessage = "Failed to update: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func updateAvatar(_ image: UIImage) async {
        guard let userId = currentUser?.id,
              let imageData = image.jpegData(compressionQuality: 0.7) else { return }
        let fileName = "\(userId).jpg"
        do {
            try await supabase.storage
                .from("avatars")
                .upload(fileName, data: imageData, options: FileOptions(upsert: true))
            let url = try supabase.storage.from("avatars").getPublicURL(path: fileName).absoluteString
            try await supabase.from("profiles").update(["avatar_url": url]).eq("id", value: userId).execute()
            self.avatarUrl = url
        } catch {
            self.errorMessage = "Avatar upload failed: \(error.localizedDescription)"
        }
    }
    
    func fetchProfileData() async {
        guard let userId = currentUser?.id else { return }

        do {
            let profile: ProfileData = try await supabase
                .from("profiles")
                .select("full_name, joined_at, dorm, class_year, bio, avatar_url")
                .eq("id", value: userId)
                .single()
                .execute()
                .value

            self.profileName = profile.full_name ?? "Unknown"
            self.dorm        = profile.dorm       ?? ""
            self.classYear   = profile.class_year ?? ""
            self.bio         = profile.bio        ?? ""
            self.avatarUrl   = profile.avatar_url

            if let dateString = profile.joined_at {
                self.joinedDate = formatJoinDate(dateString)
            }
        } catch {
            print("Profile fetch error: \(error)")
            self.profileName = "Student"
        }
    }
    
    private func formatJoinDate(_ isoString: String) -> String {
        PublicProfile.formatJoinDate(isoString)
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
    
    
    
    // MARK: - Account Deletion (Apple Requirement)
    func requestAccountDeletion() async {
        guard let userId = currentUser?.id else { return }
        
        // We grab the email or name here to send it to your new column
        let identifier = currentUser?.email ?? profileName
        
        do {
            struct DeletionRequest: Encodable {
                let user_id: UUID
                let user_identifier: String // This matches your new SQL column
            }
            
            let request = DeletionRequest(user_id: userId, user_identifier: identifier)
            
            try await supabase
                .from("deletion_requests")
                .insert(request)
                .execute()
            
            // This signs the user out immediately, satisfying Apple's requirement
            await signOut()
            
        } catch {
            print("❌ Error requesting deletion: \(error)")
        }
    }
}
