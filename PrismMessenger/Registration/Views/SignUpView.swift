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
    @Environment(\.modelContext) var context
    
    @EnvironmentObject var appLaunch: AppLaunch
    @EnvironmentObject var signupService: RegistrationService
    @EnvironmentObject var keyService: KeyService

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
            isUsernameAvailable = (await signupService.checkUsernameAvailability(username))
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
                // Step 1: Request registration and get challenge
                let challenge = try await signupService.requestRegistration(username: username)
                
                // Step 2: Sign challenge and finalize registration
                try await signupService.finalizeRegistration(username: username, challenge: challenge)
                
                // Step 3: Initialize key bundle and create user
                let (keybundle, user) = try await keyService.initializeKeyBundle(username: username)
                
                context.insert(user)
                try context.save()
                
                // Step 4: Submit key bundle
                try await keyService.submitKeyBundle(username: username, keyBundle: keybundle)

                // Handle success - mark the user as registered and set as selected account
                appLaunch.setRegistered(username: username)
                
                DispatchQueue.main.async {
                    isRegistering = false
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
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: UserData.self, configurations: config)

    SignUpView().modelContainer(container)
}
