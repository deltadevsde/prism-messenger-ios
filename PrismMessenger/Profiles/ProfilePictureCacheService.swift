//
//  ProfilePictureCacheService.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import SwiftUI

private let log = Log.profiles

@Observable @MainActor
class ProfilePictureCacheService {
    private let profilePictureRepository: ProfilePictureRepository
    private let profilePictureGateway: ProfilePictureGateway

    /// In-memory cache mapping path to ProfilePicture
    private(set) var profilePictures: [String: ProfilePicture] = [:]

    init(
        profilePictureRepository: ProfilePictureRepository,
        profilePictureGateway: ProfilePictureGateway
    ) {
        self.profilePictureRepository = profilePictureRepository
        self.profilePictureGateway = profilePictureGateway
    }

    func fetchProfilePicture(
        byPath path: String,
        downloadIfMissing: Bool = true
    ) async throws -> ProfilePicture? {
        if let profilePicture = profilePictures[path] {
            return profilePicture
        }

        if let profilePicture = try await profilePictureRepository.getProfilePicture(byPath: path) {
            return profilePicture
        }

        if downloadIfMissing {
            return try await refreshProfilePicture(byPath: path)
        } else {
            return nil
        }
    }

    func saveProfilePicture(_ profilePicture: ProfilePicture) async throws {
        try await profilePictureRepository.saveProfilePicture(profilePicture)
        profilePictures[profilePicture.path] = profilePicture
    }

    @discardableResult
    func refreshProfilePicture(byPath path: String) async throws -> ProfilePicture? {
        guard let profilePicture = try await profilePictureGateway.fetchPicture(from: path) else {
            return nil
        }

        log.debug("Profile picture fetched from server: \(path)")
        try await saveProfilePicture(profilePicture)
        return profilePicture
    }

    func populateCacheFromDisk() async {
        do {
            let profilePicturesFromDisk = try await profilePictureRepository.getAllProfilePictures()
            profilePictures = Dictionary(
                uniqueKeysWithValues: profilePicturesFromDisk.map {
                    ($0.path, $0)
                }
            )
            log.debug(
                "Profile picture cache populated with \(profilePicturesFromDisk.count) pictures from disk"
            )
        } catch {
            log
                .warning(
                    "Profile picture cache not populated, because no pictures could be fetched from disk: \(error.localizedDescription)"
                )
        }
    }
}
