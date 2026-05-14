//
//  AuthView.swift
//  CampusCloset
//
//  Created by Jun Kuang on 3/18/26.
//
import SwiftUI

struct AuthView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var isSignUp = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.18), Color(.systemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            GeometryReader { geo in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // MARK: - Branding Header
                        VStack(spacing: 10) {
                            Image("AppLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 100, height: 100)
                                .cornerRadius(22)
                                .shadow(color: Color.black.opacity(0.12), radius: 8, y: 4)

                            Text("CampusCloset")
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)

                            Text("Buy and sell on campus")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.bottom, 36)

                        if authViewModel.showConfirmationMessage {
                            confirmationUI
                                .padding(.horizontal)
                                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                        } else {
                            authFieldsUI
                                .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .trailing)))
                        }

                        Spacer(minLength: 40)
                    }
                    .frame(minHeight: geo.size.height)
                    .padding(.top, isSignUp ? 40 : geo.size.height * 0.12)
                }
            }
            .animation(.spring(response: 0.4), value: authViewModel.showConfirmationMessage)
            .animation(.spring(response: 0.35), value: isSignUp)
        }
    }

    // MARK: - Auth Form
    var authFieldsUI: some View {
        VStack(spacing: 20) {

            // Custom pill tab switcher
            HStack(spacing: 0) {
                AuthModeTab(title: "Log In", isSelected: !isSignUp) {
                    withAnimation(.spring(response: 0.3)) { isSignUp = false }
                }
                AuthModeTab(title: "Sign Up", isSelected: isSignUp) {
                    withAnimation(.spring(response: 0.3)) { isSignUp = true }
                }
            }
            .padding(4)
            .background(Color(.systemGray5))
            .cornerRadius(14)
            .padding(.horizontal)

            // Form fields
            VStack(spacing: 12) {
                if isSignUp {
                    HStack(spacing: 10) {
                        AuthField(icon: "person", placeholder: "First Name", text: $firstName, capitalize: true)
                        AuthField(icon: "person", placeholder: "Last Name", text: $lastName, capitalize: true)
                    }
                }

                AuthField(icon: "envelope", placeholder: "Email", text: $email, keyboardType: .emailAddress)
                AuthSecure(icon: "lock", placeholder: "Password", text: $password)

                if isSignUp {
                    AuthSecure(icon: "lock.shield", placeholder: "Confirm Password", text: $confirmPassword)
                }
            }
            .padding(.horizontal)

            if let error = authViewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Primary action button
            Button {
                Task {
                    if isSignUp {
                        await authViewModel.signUp(email: email, password: password, confirmPassword: confirmPassword, firstName: firstName, lastName: lastName)
                    } else {
                        await authViewModel.signIn(email: email, password: password)
                    }
                }
            } label: {
                ZStack {
                    if authViewModel.isLoading {
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text(isSignUp ? "Create Account" : "Log In")
                            .fontWeight(.semibold)
                            .font(.system(size: 17))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(14)
            }
            .padding(.horizontal)

            // MARK: - MANDATORY EULA LINK FOR APPLE REVIEW
            if isSignUp {
                Link(destination: URL(string: "https://docs.google.com/document/d/1Xoxju0dHO8gWIALPOV0z0dnVKFQe9__qMW7CNeoXwno/")!) {
                    (Text("By signing up, you agree to our ").foregroundColor(.secondary)
                    + Text("Terms of Use and EULA").foregroundColor(.blue).underline())
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)
            }
        }
        .padding(.bottom, 40)
    }

    // MARK: - Email Confirmation Screen
    var confirmationUI: some View {
        VStack(spacing: 24) {
            Image(systemName: "envelope.circle.fill")
                .font(.system(size: 72))
                .foregroundColor(.blue)

            VStack(spacing: 8) {
                Text("Check your inbox")
                    .font(.title2).bold()
                Text("We sent a confirmation link to\n**\(email)**.\nClick it to activate your account. If you don't see it, check your junk or spam folder.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            }

            VStack(spacing: 12) {
                Button {
                    Task { await authViewModel.resendConfirmationEmail(email: email) }
                } label: {
                    HStack {
                        if !authViewModel.canResendEmail { ProgressView().padding(.trailing, 4) }
                        Text(authViewModel.canResendEmail ? "Resend Email" : "Resend in \(authViewModel.resendCountdown)s")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(12)
                }
                .disabled(!authViewModel.canResendEmail)

                Button("Back to Log In") {
                    authViewModel.showConfirmationMessage = false
                    isSignUp = false
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
        }
        .padding(28)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.07), radius: 16, y: 4)
    }
}

// MARK: - Subviews

struct AuthModeTab: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .primary : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    isSelected
                        ? Color(.systemBackground)
                        : Color.clear
                )
                .cornerRadius(11)
                .shadow(color: isSelected ? Color.black.opacity(0.08) : .clear, radius: 4, y: 1)
        }
    }
}

struct AuthField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var capitalize: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 18)
            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .autocapitalization(capitalize ? .words : .none)
        }
        .padding(14)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct AuthSecure: View {
    let icon: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 18)
            SecureField(placeholder, text: $text)
        }
        .padding(14)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}
