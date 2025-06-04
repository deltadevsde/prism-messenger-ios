//
//  ProfileCacheService.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import SwiftUI

private let log = Log.profiles

@Observable @MainActor
class ProfileCacheService {
    private let profileRepository: ProfileRepository
    private let profileGateway: ProfileGateway
    private let profilePictureCacheService: ProfilePictureCacheService

    /// In-memory cache mapping UUID to Profile
    private(set) var profiles: [UUID: Profile] = [:]

    init(
        profileRepository: ProfileRepository,
        profileGateway: ProfileGateway,
        profilePictureCacheService: ProfilePictureCacheService
    ) {
        self.profileRepository = profileRepository
        self.profileGateway = profileGateway
        self.profilePictureCacheService = profilePictureCacheService
    }

    func fetchProfile(byAccountId accountId: UUID) async throws -> Profile? {
        if let profile = profiles[accountId] {
            return profile
        }

        if let profile = try await profileRepository.getProfile(byAccountId: accountId) {
            profiles[accountId] = profile
            return profile
        }

        return try await refreshProfile(byAccountId: accountId)
    }

    func fetchProfile(byUsername username: String) async throws -> Profile? {
        if let profile = (profiles.values.first { $0.username == username }) {
            return profile
        }

        if let profile = try await profileRepository.getProfile(byUsername: username) {
            profiles[profile.accountId] = profile
            return profile
        }

        return try await refreshProfile(byUsername: username)
    }

    func saveProfile(_ profile: Profile) async throws {
        try await profileRepository.saveProfile(profile)
        profiles[profile.accountId] = profile
    }

    @discardableResult
    func refreshProfile(byAccountId accountId: UUID) async throws -> Profile? {
        guard let profile = try await profileGateway.fetchProfile(byAccountId: accountId) else {
            return nil
        }

        if let profilePicturePath = profile.picture {
            try await profilePictureCacheService.refreshProfilePicture(byPath: profilePicturePath)
        }

        log.debug("Profile fetched from server: \(accountId)")
        try await saveProfile(profile)
        return profile
    }

    @discardableResult
    func refreshProfile(byUsername username: String) async throws -> Profile? {
        guard let profile = try await profileGateway.fetchProfile(byUsername: username) else {
            return nil
        }

        if let profilePicturePath = profile.picture {
            try await profilePictureCacheService.refreshProfilePicture(byPath: profilePicturePath)
        }

        log.debug("Profile fetched from server: \(profile.accountId)")
        try await saveProfile(profile)
        return profile
    }

    func populateCacheFromDisk() async {
        do {
            let profilesFromDisk = try await profileRepository.getAllProfiles()
            profiles = Dictionary(uniqueKeysWithValues: profilesFromDisk.map { ($0.accountId, $0) })
            log.debug("Profile cache populated with \(profilesFromDisk.count) profiles from disk")
        } catch {
            log
                .warning(
                    "Profile cache not populated, because no profiles could be fetched from disk: \(error.localizedDescription)"
                )
        }
    }
}
