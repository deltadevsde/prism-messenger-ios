//
//  ProfilePictureCleanupService.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation

private let log = Log.profiles

@MainActor
class ProfilePictureCleanupService {
    private let profileRepository: ProfileRepository
    private let profilePictureRepository: ProfilePictureRepository

    init(
        profileRepository: ProfileRepository,
        profilePictureRepository: ProfilePictureRepository
    ) {
        self.profileRepository = profileRepository
        self.profilePictureRepository = profilePictureRepository
    }

    /// Removes orphaned profile pictures that are not referenced by any profile
    func cleanupOrphanedProfilePictures() async throws {
        // Fetch all profiles to determine which picture paths should be retained
        let allProfiles = try await profileRepository.getAllProfiles()

        // Extract picture paths from profiles, filtering out nil values
        let pathsToRetain = allProfiles.compactMap { $0.picture }

        try await profilePictureRepository.deleteProfilePictures(notIncludedInPaths: pathsToRetain)

        log.debug("Cleaned up profile pictures (\(pathsToRetain.count) retained)")
    }
}
