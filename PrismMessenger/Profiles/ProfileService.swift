//
//  ProfileService.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation
import SwiftData

@MainActor
class ProfileService: ObservableObject {
    private let profileRepository: ProfileRepository
    private let profileGateway: ProfileGateway

    init(profileRepository: ProfileRepository, profileGateway: ProfileGateway) {
        self.profileRepository = profileRepository
        self.profileGateway = profileGateway
    }

    func fetchProfile(byAccountId accountId: UUID) async throws -> Profile? {
        // First check if there is a local entry for the profile
        if let localProfile = try await profileRepository.getProfile(byAccountId: accountId) {
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

    func fetchProfile(byUsername username: String) async throws -> Profile? {
        // First check if there is a local entry for the profile
        if let localProfile = try await profileRepository.getProfile(byUsername: username) {
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

    func deleteProfile(_ profile: Profile) async throws {
        try await profileRepository.deleteProfile(profile)
    }
}
