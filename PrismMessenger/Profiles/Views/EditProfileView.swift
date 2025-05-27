//
//  ProfileView.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import PhotosUI
import SwiftUI

private let imageSize: CGFloat = 150

struct EditProfileView: View {
    @EnvironmentObject private var router: NavigationRouter
    @Environment(ProfileService.self) private var profileService

    @State private var isEditing = false
    @State private var newDisplayName = ""
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        ZStack {
            if let profile = profileService.ownProfile {
                profileView(for: profile)
            } else {
                ProgressView()
            }
        }
        .onAppear {
            Task {
                do {
                    try await profileService.loadOwnProfile()
                } catch {
                    print(error)
                }
            }
        }
    }

    private func profileView(for profile: Profile) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                HStack {
                    Text("Profile")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Spacer()
                    Button("Edit Profile") {
                        isEditing = true
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)
                }.padding(.horizontal)

                ProfilePictureView(profile: profile)

                if isEditing {
                    PhotosPicker(
                        selection: $selectedPhotoItem,
                        matching: .images
                    ) {
                        Text("Select Photo")
                    }.onChange(of: selectedPhotoItem) { _, newItem in
                        Task {
                            do {
                                guard
                                    let imageData = try? await newItem?.loadTransferable(
                                        type: Data.self)
                                else {
                                    return
                                }

                                try await profileService.updateProfilePicture(with: imageData)
                            } catch {
                                print(error)
                            }
                        }
                    }
                }

                // Display Name, Username
                VStack(spacing: 4) {
                    if isEditing {
                        VStack(spacing: 10) {

                            TextField("Display Name", text: $newDisplayName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.horizontal, 40)
                                .onAppear {
                                    newDisplayName = profile.displayName ?? ""
                                }

                            HStack {
                                Button("Cancel") {
                                    isEditing = false
                                }
                                .buttonStyle(.bordered)

                                Button("Save") {
                                    let displayName = newDisplayName.isEmpty ? nil : newDisplayName
                                    Task {
                                        do {
                                            try await profileService.updateDisplayName(displayName)
                                            isEditing = false
                                        } catch {
                                            print(error)
                                        }
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                        .padding(.vertical, 5)
                    } else {
                        if let displayName = profile.displayName {
                            Text(displayName)
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
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

struct ProfilePictureView: View {
    var profile: Profile

    var body: some View {
        if let profilePicture = profile.picture,
           let imageUrl = URL(string: profilePicture)
        {
            AsyncImage(url: imageUrl) { phase in
                switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: imageSize, height: imageSize)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: imageSize, height: imageSize)
                            .clipShape(Circle())
                    case .failure(let error):
                        textBasedProfilePicture
                            .padding(.top)
                        Text("Failure: \(String(describing: error))")
                            .foregroundColor(.red)
                    @unknown default:
                        EmptyView()
                }
            }
        } else {
            textBasedProfilePicture
                .padding(.top)
        }
    }

    private var textBasedProfilePicture: some View {
        ZStack {
            Circle()
                .fill(generateColor(from: profile.username))
                .frame(width: imageSize, height: imageSize)

            Text(String(profile.username.first ?? Character("?")))
                .font(.system(size: imageSize * 0.4))
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
        EditProfileView()
    } withSetup: { appContext in
        try await appContext.registrationService.registerNewUser(username: "Alice")
    }
}
