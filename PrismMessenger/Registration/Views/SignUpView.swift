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
    
    @EnvironmentObject var signupService: RegistrationService
    @EnvironmentObject var keyService: KeyService

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
                
                let (keybundle, user) = try await keyService.initializeKeyBundle(username: username)
                context.insert(user)
                try context.save()
                
                try await keyService.submitKeyBundle(username: username, keyBundle: keybundle)

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
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: UserData.self, configurations: config)

    SignUpView().modelContainer(container)
}
