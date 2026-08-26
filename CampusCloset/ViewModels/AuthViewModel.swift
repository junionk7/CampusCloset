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
            self.errorMessage = friendlyMessage(
                for: error,
                fallback: "We couldn't create your account. Please try again."
            )
        }
        isLoading = false
    }

    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil

        do {
            try await supabase.auth.signIn(email: email, password: password)
        } catch {
            self.errorMessage = friendlyMessage(
                for: error,
                fallback: "We couldn't log you in. Please try again."
            )
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
            self.errorMessage = friendlyMessage(
                for: error,
                fallback: "We couldn't save your profile changes. Please try again."
            )
        }
        isLoading = false
    }

    /// One year, in seconds. Safe despite the file being overwritable, because
    /// the URL saved on the profile carries a ?v= marker that changes with every
    /// upload — see below.
    private static let avatarCacheControl = "31536000"

    func updateAvatar(_ image: UIImage) async {
        // A profile photo is never shown larger than 90pt, so there is no reason
        // to store the original camera file.
        guard let userId = currentUser?.id,
              let imageData = ImageProcessing.jpegData(
                  from: image,
                  maxEdge: ImageProcessing.avatarMaxEdge,
                  quality: 0.8
              ) else { return }

        // The storage path deliberately stays "<userId>.jpg": the avatars bucket
        // policy is keyed on it. Cache-busting happens in the saved URL instead,
        // which is what lets the file be cached for a year and still update
        // instantly when someone changes their photo.
        let fileName = "\(userId).jpg"
        do {
            try await supabase.storage
                .from("avatars")
                .upload(fileName, data: imageData, options: FileOptions(
                    cacheControl: Self.avatarCacheControl,
                    contentType: "image/jpeg",
                    upsert: true
                ))
            let baseUrl = try supabase.storage.from("avatars").getPublicURL(path: fileName).absoluteString
            let url = "\(baseUrl)?v=\(Int(Date().timeIntervalSince1970))"
            try await supabase.from("profiles").update(["avatar_url": url]).eq("id", value: userId).execute()
            self.avatarUrl = url
        } catch {
            self.errorMessage = friendlyMessage(
                for: error,
                fallback: "We couldn't upload that photo. Please try again."
            )
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
            self.errorMessage = friendlyMessage(
                for: error,
                fallback: "We couldn't resend the confirmation email. Please try again."
            )
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
            self.errorMessage = friendlyMessage(
                for: error,
                fallback: "We couldn't sign you out. Please try again."
            )
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

// MARK: - Human-readable error messages

/// Supabase writes its errors for developers — "Invalid login credentials",
/// "Email not confirmed", raw HTTP status text. Students see these on the
/// sign-in screen, so each one a person can realistically hit gets a sentence
/// that says what actually happened and what to do next.
private enum AuthMessage {
    static let badCredentials = "That email and password don't match an account. Check for typos, or tap Sign Up if you don't have an account yet."
    static let emailNotConfirmed = "Please confirm your email before logging in. We sent you a link — check your inbox, and your junk folder too."
    static let accountExists = "An account with that email already exists. Try logging in instead."
    static let weakPassword = "That password is too easy to guess. Use at least 6 characters, and mix in some numbers."
    static let samePassword = "That's already your password. Please choose a different one."
    static let invalidEmail = "That doesn't look like a valid email address. Please check it and try again."
    static let tooManyAttempts = "Too many tries. Please wait a minute, then try again."
    static let banned = "This account has been suspended. Email us if you think that's a mistake."
    static let signupsClosed = "New sign-ups are turned off at the moment. Please try again later."
    static let emailNotAllowed = "We can't send email to that address. Please use a different one."
    static let sessionExpired = "You've been signed out. Please log in again."
    static let offline = "You're not connected to the internet. Check your Wi-Fi or data and try again."
    static let timedOut = "That took too long. Check your connection and try again."
    static let unreachable = "We couldn't reach Campus Closet. Check your connection and try again."
}

private extension AuthViewModel {

    /// Maps an error to something a student can act on. `fallback` covers the
    /// cases we can't identify, so the sentence still fits what they were doing.
    func friendlyMessage(for error: Error, fallback: String) -> String {
        if let authError = error as? AuthError {
            if let known = message(for: authError.errorCode) { return known }
            // Older Supabase deployments return a generic code and put the real
            // detail only in the message text, so check that before giving up.
            if let matched = message(matching: authError.message) { return matched }
            return fallback
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return AuthMessage.offline
            case .timedOut:
                return AuthMessage.timedOut
            default:
                return AuthMessage.unreachable
            }
        }

        return fallback
    }

    func message(for code: ErrorCode) -> String? {
        switch code {
        case .invalidCredentials, .userNotFound:
            return AuthMessage.badCredentials
        case .emailNotConfirmed:
            return AuthMessage.emailNotConfirmed
        case .emailExists, .userAlreadyExists:
            return AuthMessage.accountExists
        case .weakPassword:
            return AuthMessage.weakPassword
        case .samePassword:
            return AuthMessage.samePassword
        case .validationFailed:
            return AuthMessage.invalidEmail
        case .overRequestRateLimit, .overEmailSendRateLimit:
            return AuthMessage.tooManyAttempts
        case .userBanned:
            return AuthMessage.banned
        case .signupDisabled, .emailProviderDisabled:
            return AuthMessage.signupsClosed
        case .emailAddressNotAuthorized:
            return AuthMessage.emailNotAllowed
        case .sessionExpired, .sessionNotFound:
            return AuthMessage.sessionExpired
        case .requestTimeout:
            return AuthMessage.timedOut
        default:
            return nil
        }
    }

    func message(matching serverText: String) -> String? {
        let text = serverText.lowercased()
        if text.contains("invalid login credentials") || text.contains("invalid credentials") {
            return AuthMessage.badCredentials
        }
        if text.contains("email not confirmed") || text.contains("not confirmed") {
            return AuthMessage.emailNotConfirmed
        }
        if text.contains("already registered") || text.contains("already exists") {
            return AuthMessage.accountExists
        }
        if text.contains("rate limit") || text.contains("too many") {
            return AuthMessage.tooManyAttempts
        }
        if text.contains("password") && text.contains("weak") {
            return AuthMessage.weakPassword
        }
        if text.contains("unable to validate email") || text.contains("invalid email") {
            return AuthMessage.invalidEmail
        }
        return nil
    }
}
