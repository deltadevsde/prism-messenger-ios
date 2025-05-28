//
//  OtherProfileService.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation
import SwiftData
import SwiftUI

private let log = Log.profiles

@Observable @MainActor
class OtherProfileService {
    private let profileRepository: ProfileRepository
    private let profileGateway: ProfileGateway

    init(
        profileRepository: ProfileRepository,
        profileGateway: ProfileGateway
    ) {
        self.profileRepository = profileRepository
        self.profileGateway = profileGateway
    }

    // MARK: - Profile Fetching

    func fetchProfile(
        byAccountId accountId: UUID,
        usingLocalCache shouldUseLocalCache: Bool = true
    ) async throws -> Profile? {
        // First check if there is a local entry for the profile
        if shouldUseLocalCache,
            let localProfile = try await profileRepository.getProfile(byAccountId: accountId)
        {
            return localProfile
        }

        // If no local entry exists, fetch from remote
        guard let remoteProfile = try await profileGateway.fetchProfile(byAccountId: accountId)
        else {
            return nil
        }

        // Save the fetched profile locally
        try await profileRepository.saveProfile(remoteProfile)
        return remoteProfile
    }

    func fetchProfile(
        byUsername username: String,
        usingLocalCache shouldUseLocalCache: Bool = true
    ) async throws -> Profile? {
        // First check if there is a local entry for the profile
        if shouldUseLocalCache,
            let localProfile = try await profileRepository.getProfile(byUsername: username)
        {
            return localProfile
        }

        // If no local entry exists, fetch from remote
        guard let remoteProfile = try await profileGateway.fetchProfile(byUsername: username) else {
            return nil
        }

        // Save the fetched profile locally
        try await profileRepository.saveProfile(remoteProfile)
        return remoteProfile
    }
}