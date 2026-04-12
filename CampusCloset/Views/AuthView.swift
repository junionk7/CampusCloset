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
        NavigationStack {
            VStack(spacing: 20) {
                // Header Section
                Image(systemName: "bag.fill")
                    .resizable()
                    .frame(width: 80, height: 80)
                    .foregroundColor(.blue)
                    .padding(.bottom, 10)
                
                if authViewModel.showConfirmationMessage {
                    confirmationUI
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                } else {
                    authFieldsUI
                        .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .trailing)))
                }
            }
            .padding()
            .animation(.spring(), value: authViewModel.showConfirmationMessage)
        }
    }
    
    var authFieldsUI: some View {
        VStack(spacing: 15) {
            Text(isSignUp ? "Create Account" : "Welcome Back")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(spacing: 15) {
                if isSignUp {
                    HStack {
                        TextField("First Name", text: $firstName)
                            .textFieldStyle(.roundedBorder)
                        
                        TextField("Last Name", text: $lastName)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                
                TextField("Email", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                
                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                
                if isSignUp {
                    SecureField("Confirm Password", text: $confirmPassword)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .padding(.horizontal)
            
            if let error = authViewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            
            Button {
                Task {
                    if isSignUp {
                        await authViewModel.signUp(
                            email: email,
                            password: password,
                            confirmPassword: confirmPassword,
                            firstName: firstName,
                            lastName: lastName
                        )
                    } else {
                        await authViewModel.signIn(email: email, password: password)
                    }
                }
            } label: {
                if authViewModel.isLoading {
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text(isSignUp ? "Sign Up" : "Log In").fontWeight(.bold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            .padding(.horizontal)
            
            Button {
                withAnimation { isSignUp.toggle() }
            } label: {
                Text(isSignUp ? "Already have an account? Log In" : "Don't have an account? Sign Up")
                    .font(.footnote)
            }
        }
    }
    
    var confirmationUI: some View {
        VStack(spacing: 25) {
            Image(systemName: "envelope.circle.fill")
                .font(.system(size: 70))
                .foregroundColor(.blue)
            
            VStack(spacing: 10) {
                Text("Verify your email").font(.title2).bold()
                Text("We sent a link to **\(email)**.\nPlease click it to activate your account.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 15) {
                Button {
                    Task { await authViewModel.resendConfirmationEmail(email: email) }
                } label: {
                    HStack {
                        if !authViewModel.canResendEmail { ProgressView().padding(.trailing, 5) }
                        Text(authViewModel.canResendEmail ? "Resend Email" : "Resend in \(authViewModel.resendCountdown)s")
                    }
                    .fontWeight(.semibold)
                }
                .disabled(!authViewModel.canResendEmail)
                
                Button("Back to Login") {
                    authViewModel.showConfirmationMessage = false
                    isSignUp = false
                }
                .font(.callout)
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(20)
    }
}
