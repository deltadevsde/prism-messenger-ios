//
//  ProfileView.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import CryptoKit
import SwiftData
import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var router: NavigationRouter
    @EnvironmentObject private var userService: UserService

    @State private var isEditingDisplayName = false
    @State private var newDisplayName = ""
    @State private var currentUser: User?

    var body: some View {
        ZStack {
            if let user = userService.currentUser {
                profileView(for: user)
            } else {
                ProgressView()
            }
        }
    }

    private func profileView(for user: User) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                HStack {
                    Text("Profile")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Spacer()
                    Button("Edit Profile") {
                        isEditingDisplayName = true
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)
                }.padding(.horizontal)

                // Profile Image
                ProfileImageView(username: user.username)
                    .padding(.top)

                // Display Name, Username, and Public Key
                VStack(spacing: 4) {
                    if isEditingDisplayName {
                        VStack(spacing: 10) {
                            TextField("Display Name", text: $newDisplayName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.horizontal, 40)
                                .onAppear {
                                    newDisplayName = user.displayName ?? ""
                                }

                            HStack {
                                Button("Cancel") {
                                    isEditingDisplayName = false
                                }
                                .buttonStyle(.bordered)

                                Button("Save") {
                                    user.displayName = newDisplayName.isEmpty ? nil : newDisplayName
                                    Task { try await userService.saveUser(user) }
                                    isEditingDisplayName = false
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                        .padding(.vertical, 5)
                    } else {
                        if let displayName = user.displayName {
                            Text(displayName)
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                    }

                    Text("@\(user.username)")
                        .font(.title3)
                        .fontWeight(.medium)
                        .padding(.top, 1)

                    Text(formatPublicKeyPreview(from: user))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.top, 1)
                }

                Spacer()
            }
            .padding(.bottom)
        }
    }

    private func formatPublicKeyPreview(from user: User) -> String {
        let publicKey = user.signedPrekey.publicKey
        let keyData = publicKey.rawRepresentation
        let keyString = keyData.base64EncodedString()

        // Show just the first 8 and last 8 characters with ... in between
        if keyString.count > 16 {
            let prefix = keyString.prefix(8)
            let suffix = keyString.suffix(8)
            return "\(prefix)...\(suffix)"
        }
        return keyString
    }
}

struct ProfileImageView: View {
    let username: String
    var size: CGFloat = 150

    var body: some View {
        ZStack {
            Circle()
                .fill(generateColor(from: username))
                .frame(width: size, height: size)

            Text(String(username.first ?? Character("?")))
                .font(.system(size: size * 0.4))
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
    }

    private func generateColor(from string: String) -> Color {
        let hash = string.utf8.reduce(0) { $0 + Int($1) }

        // Generate consistent but diverse hues based on hash
        let hue = Double(hash % 360) / 360.0

        // Use medium-high saturation and brightness for vibrant but not harsh colors
        return Color(hue: hue, saturation: 0.7, brightness: 0.8)
    }
}

#Preview {
    AsyncPreview {
        ProfileView()
    }
    withSetup: { appContext in
        try! await appContext.registrationService.registerNewUser(username: "Alice")
    }
}
