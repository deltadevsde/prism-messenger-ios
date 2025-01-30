//
//  ContentView.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Combine
import SwiftUI

struct SignUpView: View {
    @EnvironmentObject var signupService: RegistrationService

    @State private var username = ""
    @State private var isUsernameAvailable = false
    @State private var isCheckingUsername = false

    private var debounceTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    private var cancellables = Set<AnyCancellable>()

    var body: some View {
        VStack(alignment: .leading) {
            TextField("Username", text: $username)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onChange(of: username) {
                    handleUsernameChange()
                }

            availabilityStatusView

            Button("Create Account") {
                handleCreateAccount()
            }
            .disabled(!isUsernameAvailable)
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

    private func handleCreateAccount() {
        Task {
            do {
                try await signupService.register(username: username)
                // Handle success
                // TODO How to proceed from here?
                // Wait until settled on prism?
            } catch let error {
                print(error)
            }
        }
    }
}

#Preview {
    SignUpView()
}
