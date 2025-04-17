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
    @EnvironmentObject var navState: AppNavigationState
    @EnvironmentObject var registrationService: RegistrationService
    @Environment(\.dismiss) private var dismiss

    @State private var username = ""
    @State private var debouncedUsername = ""
    @State private var isUsernameAvailable = false
    @State private var isCheckingUsername = false

    @State private var usernameWorkItem: DispatchWorkItem?

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
        usernameWorkItem?.cancel()

        isUsernameAvailable = false
        isCheckingUsername = !username.isEmpty

        let workItem = DispatchWorkItem {
            debouncedUsername = username

            checkAvailability()
        }

        usernameWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }

    private func checkAvailability() {
        guard !debouncedUsername.isEmpty else {
            isCheckingUsername = false
            return
        }

        isCheckingUsername = true

        Task {
            isUsernameAvailable = (await registrationService.checkUsernameAvailability(debouncedUsername))
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

                navState.launchState = .ready

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
    let appContext = AppContext.forPreview()

    SignUpView()
        .environmentObject(appContext.navState)
        .environmentObject(appContext.registrationService)
}
