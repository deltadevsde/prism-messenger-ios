//
//  OwnProfileService.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation
import SwiftData
import SwiftUI

private let log = Log.profiles

enum ProfileServiceError: Error {
    case notAuthenticated
    case profileUpdateFailed
    case pictureUploadFailed
    case invalidImage
}

@Observable @MainActor
class OwnProfileService {
    private let profileRepository: ProfileRepository
    private let profileGateway: ProfileGateway
    private let profilePictureGateway: ProfilePictureGateway
    private let profilePictureCacheService: ProfilePictureCacheService
    private let userService: UserService

    var ownProfile: Profile?

    init(
        profileRepository: ProfileRepository,
        profileGateway: ProfileGateway,
        profilePictureGateway: ProfilePictureGateway,
        profilePictureCacheService: ProfilePictureCacheService,
        userService: UserService
    ) {
        self.profileRepository = profileRepository
        self.profileGateway = profileGateway
        self.profilePictureGateway = profilePictureGateway
        self.profilePictureCacheService = profilePictureCacheService
        self.userService = userService
    }

    // MARK: - Own Profile Loading

    func loadOwnProfile() async throws {
        guard let currentUser = userService.currentUser else {
            throw ProfileServiceError.notAuthenticated
        }

        // First check if there is a local entry for the profile
        if let localProfile = try await profileRepository.getProfile(byAccountId: currentUser.id) {
            ownProfile = localProfile
            return
        }

        // If no local entry exists, fetch from remote
        guard let remoteProfile = try await profileGateway.fetchProfile(byAccountId: currentUser.id)
        else {
            ownProfile = nil
            return
        }

        // Save the fetched profile locally
        try await profileRepository.saveProfile(remoteProfile)
        ownProfile = remoteProfile
    }

    // MARK: - Profile Updates

    /// Update the display name of the current user's profile
    func updateDisplayName(_ newDisplayName: String?) async throws {
        let request = UpdateProfileRequest(
            displayName: newDisplayName,
            profilePictureAction: .noChange
        )

        // Update remote profile
        _ = try await profileGateway.updateProfile(request)

        // Update local profile
        if let profile = ownProfile {
            profile.displayName = newDisplayName
            try await profileRepository.saveProfile(profile)
        }
    }

    /// Remove the current profile picture
    func clearProfilePicture() async throws {
        let request = UpdateProfileRequest(
            displayName: nil,
            profilePictureAction: .clear
        )

        // Update remote profile
        _ = try await profileGateway.updateProfile(request)

        // Update local profile
        if let profile = ownProfile {
            profile.picture = nil
            try await profileRepository.saveProfile(profile)
        }
    }

    /// Convenience method to update profile picture with image data
    /// Handles the entire flow of getting upload URL, uploading, and updating model
    func updateProfilePicture(with imageData: Data) async throws {
        guard let profile = ownProfile else {
            log.warning("Own profile cannot be updated, because it does not exist")
            return
        }

        let request = UpdateProfileRequest(
            displayName: nil,
            profilePictureAction: .update
        )

        // Request profile picture update from gateway
        guard let uploadResponse = try await profileGateway.updateProfile(request) else {
            throw ProfileServiceError.profileUpdateFailed
        }

        let picture = ProfilePicture(path: uploadResponse.pictureUrl, data: imageData)

        do {
            // Upload the image using the picture gateway
            try await profilePictureGateway.uploadPicture(picture, to: uploadResponse.uploadUrl)
            try? await profilePictureCacheService.saveProfilePicture(picture)
        } catch {
            throw ProfileServiceError.pictureUploadFailed
        }

        profile.picture = uploadResponse.pictureUrl
        try await profileRepository.saveProfile(profile)
    }
}
