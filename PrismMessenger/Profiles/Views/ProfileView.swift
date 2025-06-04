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
    @Environment(ProfileCacheService.self) private var profileCacheService

    @State private var error: String?

    var body: some View {
        ZStack {
            if let profile = profileCacheService.profiles[userId] {
                profileView(for: profile)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            Task {
                try await profileCacheService.refreshProfile(byAccountId: userId)
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
}

#Preview {
    AsyncPreview {
        ProfileView(userId: UUID())
    } withSetup: { appContext in
        try await appContext.registrationService.registerNewUser(username: "johndoe")
    }
}
