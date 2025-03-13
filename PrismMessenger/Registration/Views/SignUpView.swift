//
//  ContentView.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Combine
import SwiftData
import CryptoKit
import SwiftUI

struct SignUpView: View {
    @EnvironmentObject var appLaunch: AppLaunch
    @EnvironmentObject var registrationService: RegistrationService
    @Environment(\.dismiss) private var dismiss
    
    @State private var username = ""
    @State private var isUsernameAvailable = false
    @State private var isCheckingUsername = false
    
    private var debounceTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Create a New Account")
                .font(.title)
                .fontWeight(.bold)
                .padding(.bottom)
            
            TextField("Username", text: $username)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .disabled(isRegistering)
                .onChange(of: username) {
                    handleUsernameChange()
                }

            availabilityStatusView
            
            if let error = registrationError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.top, 5)
            }
            
            Spacer()

            Button(action: handleCreateAccount) {
                if isRegistering {
                    HStack {
                        ProgressView()
                            .tint(.white)
                        Text("Creating Account...")
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.7))
                    .cornerRadius(10)
                } else {
                    Text("Create Account")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isUsernameAvailable ? Color.blue : Color.gray)
                        .cornerRadius(10)
                }
            }
            .disabled(!isUsernameAvailable || isRegistering)
        }
        .padding()
        .onReceive(debounceTimer) { _ in
            checkAvailability()
        }
    }

    private var availabilityStatusView: some View {
        Group {
            if isCheckingUsername {
                ProgressView()
            } else if !username.isEmpty {
                Text(isUsernameAvailable ? "Username available" : "Username taken")
                    .foregroundColor(isUsernameAvailable ? .green : .red)
                    .font(.caption)
            }
        }
    }

    private func handleUsernameChange() {
        isUsernameAvailable = false
        isCheckingUsername = true
    }

    private func checkAvailability() {
        guard !username.isEmpty else {
            isCheckingUsername = false
            return
        }

        Task {
            isUsernameAvailable = (await registrationService.checkUsernameAvailability(username))
            isCheckingUsername = false
        }
    }

    @State private var isRegistering = false
    @State private var registrationError: String?
    
    private func handleCreateAccount() {
        isRegistering = true
        registrationError = nil
        
        Task {
            do {
                try await registrationService.registerNewUser(username: username)

                appLaunch.setRegistered()
                
                DispatchQueue.main.async {
                    isRegistering = false
                    // Dismiss current view to return to root view
                    dismiss()
                }
            } catch let error {
                print("Registration error: \(error)")
                DispatchQueue.main.async {
                    isRegistering = false
                    registrationError = "Registration failed: \(error.localizedDescription)"
                }
            }
        }
    }
}

#Preview {
    SignUpView()
}
