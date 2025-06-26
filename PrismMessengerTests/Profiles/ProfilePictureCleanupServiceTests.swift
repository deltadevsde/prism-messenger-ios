//
//  ProfilePictureCleanupServiceTests.swift
//  PrismMessengerTests
//
//  Copyright © 2025 prism. All rights reserved.
//

import Testing
import Foundation

@testable import PrismMessenger

private enum TestError: Error {
    case someError
}

/// Mock implementation of ProfileRepository for testing
@MainActor
private class MockProfileRepository: ProfileRepository {
    var getAllProfilesReturnValue: [Profile] = []
    var getAllProfilesError: Error? = nil
    var getAllProfilesCallCount = 0

    func getProfile(byAccountId accountId: UUID) async throws -> Profile? {
        return nil
    }

    func getProfile(byUsername username: String) async throws -> Profile? {
        return nil
    }

    func getAllProfiles() async throws -> [Profile] {
        getAllProfilesCallCount += 1
        
        if let error = getAllProfilesError {
            throw error
        }
        
        return getAllProfilesReturnValue
    }

    func saveProfile(_ profile: Profile) async throws {}

    func deleteProfile(_ profile: Profile) async throws {}
}

/// Mock implementation of ProfilePictureRepository for testing
@MainActor
private class MockProfilePictureRepository: ProfilePictureRepository {
    var deleteProfilePicturesCallCount = 0
    var deleteProfilePicturesLastCalledWithPaths: [String] = []
    var deleteProfilePicturesError: Error? = nil

    func getProfilePicture(byPath path: String) async throws -> ProfilePicture? {
        return nil
    }

    func getAllProfilePictures() async throws -> [ProfilePicture] {
        return []
    }

    func saveProfilePicture(_ profilePicture: ProfilePicture) async throws {}

    func deleteProfilePictures(notIncludedInPaths pathsToRetain: [String]) async throws {
        deleteProfilePicturesCallCount += 1
        deleteProfilePicturesLastCalledWithPaths = pathsToRetain
        
        if let error = deleteProfilePicturesError {
            throw error
        }
    }
}

@MainActor
final class ProfilePictureCleanupServiceTests {

    private let profileRepository: MockProfileRepository
    private let profilePictureRepository: MockProfilePictureRepository
    private let service: ProfilePictureCleanupService

    init() {
        profileRepository = MockProfileRepository()
        profilePictureRepository = MockProfilePictureRepository()
        service = ProfilePictureCleanupService(
            profileRepository: profileRepository,
            profilePictureRepository: profilePictureRepository
        )
    }

    // MARK: - Tests

    @Test
    func cleanupOrphanedProfilePicturesWithValidPaths() async throws {
        // Set up test profiles with picture paths
        let profile1 = Profile(
            accountId: UUID(),
            username: "user1",
            displayName: "User One",
            picture: "path/to/picture1.jpg"
        )
        let profile2 = Profile(
            accountId: UUID(),
            username: "user2",
            displayName: "User Two",
            picture: "path/to/picture2.jpg"
        )
        let profile3 = Profile(
            accountId: UUID(),
            username: "user3",
            displayName: "User Three",
            picture: nil
        )
        
        profileRepository.getAllProfilesReturnValue = [profile1, profile2, profile3]

        // Execute cleanup
        try await service.cleanupOrphanedProfilePictures()

        // Verify that getAllProfiles was called
        #expect(profileRepository.getAllProfilesCallCount == 1)

        // Verify that deleteProfilePictures was called with correct paths
        #expect(profilePictureRepository.deleteProfilePicturesCallCount == 1)
        #expect(profilePictureRepository.deleteProfilePicturesLastCalledWithPaths.count == 2)
        #expect(profilePictureRepository.deleteProfilePicturesLastCalledWithPaths.contains("path/to/picture1.jpg"))
        #expect(profilePictureRepository.deleteProfilePicturesLastCalledWithPaths.contains("path/to/picture2.jpg"))
    }

    @Test
    func cleanupOrphanedProfilePicturesWithNoProfiles() async throws {
        // Set up empty profiles array
        profileRepository.getAllProfilesReturnValue = []

        // Execute cleanup
        try await service.cleanupOrphanedProfilePictures()

        // Verify that getAllProfiles was called
        #expect(profileRepository.getAllProfilesCallCount == 1)

        // Verify that deleteProfilePictures was called with empty paths array
        #expect(profilePictureRepository.deleteProfilePicturesCallCount == 1)
        #expect(profilePictureRepository.deleteProfilePicturesLastCalledWithPaths.isEmpty)
    }

    @Test
    func cleanupOrphanedProfilePicturesHandlesProfileRepositoryError() async throws {
        // Set up profile repository to throw an error
        profileRepository.getAllProfilesError = TestError.someError

        // Verify that the error is propagated
        await #expect(throws: TestError.self) {
            try await service.cleanupOrphanedProfilePictures()
        }

        // Verify that getAllProfiles was called
        #expect(profileRepository.getAllProfilesCallCount == 1)

        // Verify that deleteProfilePictures was not called due to error
        #expect(profilePictureRepository.deleteProfilePicturesCallCount == 0)
    }

    @Test
    func cleanupOrphanedProfilePicturesHandlesProfilePictureRepositoryError() async throws {
        // Set up valid profiles
        let profile = Profile(
            accountId: UUID(),
            username: "user1",
            displayName: "User One",
            picture: "path/to/picture1.jpg"
        )
        profileRepository.getAllProfilesReturnValue = [profile]

        // Set up profile picture repository to throw an error
        profilePictureRepository.deleteProfilePicturesError = TestError.someError

        // Verify that the error is propagated
        await #expect(throws: TestError.self) {
            try await service.cleanupOrphanedProfilePictures()
        }

        // Verify that both repositories were called
        #expect(profileRepository.getAllProfilesCallCount == 1)
        #expect(profilePictureRepository.deleteProfilePicturesCallCount == 1)
    }
}
