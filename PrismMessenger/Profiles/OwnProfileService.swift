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
    private let profileGateway: ProfileGateway
    private let profilePictureGateway: ProfilePictureGateway
    private let profileCacheService: ProfileCacheService
    private let profilePictureCacheService: ProfilePictureCacheService
    private let userService: UserService

    var ownProfile: Profile? {
        guard let ownAccountId = userService.currentUser?.id else {
            return nil
        }
        return profileCacheService.profiles[ownAccountId]
    }

    init(
        profileGateway: ProfileGateway,
        profilePictureGateway: ProfilePictureGateway,
        profileCacheService: ProfileCacheService,
        profilePictureCacheService: ProfilePictureCacheService,
        userService: UserService
    ) {
        self.profileGateway = profileGateway
        self.profilePictureGateway = profilePictureGateway
        self.profileCacheService = profileCacheService
        self.profilePictureCacheService = profilePictureCacheService
        self.userService = userService
    }

    // MARK: - Own Profile Loading

    func refreshOwnProfile() async throws {
        guard let currentUser = userService.currentUser else {
            throw ProfileServiceError.notAuthenticated
        }
        try await profileCacheService.refreshProfile(byAccountId: currentUser.id)
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

        // Update profile cache
        if let profile = ownProfile {
            profile.displayName = newDisplayName
            try await profileCacheService.saveProfile(profile)
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

        // Update profile cache
        if let profile = ownProfile {
            profile.picture = nil
            try await profileCacheService.saveProfile(profile)
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
        try await profileCacheService.saveProfile(profile)
    }
}
