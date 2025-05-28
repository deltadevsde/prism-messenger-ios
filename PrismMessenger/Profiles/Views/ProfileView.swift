//
//  ProfileView.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import SwiftUI

private let imageSize: CGFloat = 150

struct ProfileView: View {
    let userId: UUID
    @EnvironmentObject private var router: NavigationRouter
    @Environment(ProfileService.self) private var profileService

    @State private var profile: Profile?
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        ZStack {
            if isLoading {
                ProgressView()
            } else if let profile = profile {
                profileView(for: profile)
            } else if let error = error {
                errorView(error: error)
            } else {
                Text("Profile not found")
                    .foregroundColor(.gray)
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            Task {
                await loadProfile()
            }
        }
    }

    private func profileView(for profile: Profile) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                ProfilePictureView(profile: profile)

                // Display Name, Username
                VStack(spacing: 4) {
                    if let displayName = profile.displayName {
                        Text(displayName)
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    Text("@\(profile.username)")
                        .font(.title3)
                        .fontWeight(.medium)
                        .padding(.top, 1)
                }

                Spacer()
            }
            .padding(.bottom)
        }
    }

    private func errorView(error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.red)

            Text("Failed to load profile")
                .font(.headline)

            Text(error)
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)

            Button("Try Again") {
                Task {
                    await loadProfile()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private func loadProfile() async {
        isLoading = true
        error = nil

        do {
            profile = try await profileService.fetchProfile(byAccountId: userId)
            isLoading = false
        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
    }
}

#Preview {
    AsyncPreview {
        ProfileView(userId: UUID())
    } withSetup: { appContext in
        try await appContext.registrationService.registerNewUser(username: "johndoe")
    }
}
