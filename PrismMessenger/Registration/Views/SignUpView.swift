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
    @EnvironmentObject var router: NavigationRouter
    @EnvironmentObject var registrationService: RegistrationService
    @Environment(\.dismiss) private var dismiss

    @State private var username = ""
    @State private var debouncedUsername = ""
    @State private var isUsernameAvailable = false
    @State private var isCheckingUsername = false

    @State private var usernameWorkItem: DispatchWorkItem?

    var body: some View {
        VStack(alignment: .leading) {
            Text("Create Username")
                .font(.title)
                .fontWeight(.semibold)

            Text("Please create a unique username.\nOnce set, it cannot be changed.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fontWeight(.medium)
                .padding(.bottom)

            HStack {
                Text("@")
                    .foregroundColor(.black)
                    .bold()

                TextField("Username", text: $username)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .disabled(isRegistering)
                    .onChange(of: username) {
                        handleUsernameChange()
                    }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)

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
                    .background(.blue.opacity(0.7))
                    .cornerRadius(10)
                } else {
                    Text("Continue")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.black.opacity(isUsernameAvailable ? 1.0 : 0.5))
                        .cornerRadius(30)
                }
            }
            .disabled(!isUsernameAvailable || isRegistering)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 30)
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

                router.setLaunchState(.registered)

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
    AsyncPreview {
        SignUpView()
    }
}
