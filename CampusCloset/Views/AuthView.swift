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
    @State private var isSignUp = false // Toggle between Login and Sign Up
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "bag.fill")
                    .resizable()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.blue)
                    .padding(.bottom, 20)
                
                Text(isSignUp ? "Create Account" : "Welcome Back")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                VStack(spacing: 15) {
                    TextField("Email", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.horizontal)
                
                if let error = authViewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                Button {
                    Task {
                        if isSignUp {
                            await authViewModel.signUp(email: email, password: password)
                        } else {
                            await authViewModel.signIn(email: email, password: password)
                        }
                    }
                } label: {
                    if authViewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text(isSignUp ? "Sign Up" : "Log In")
                            .fontWeight(.bold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal)
                
                Button {
                    isSignUp.toggle()
                } label: {
                    Text(isSignUp ? "Already have an account? Log In" : "Don't have an account? Sign Up")
                        .font(.footnote)
                }
            }
            .padding()
        }
    }
}

#Preview {
    AuthView().environmentObject(AuthViewModel())
}
