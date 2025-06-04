//
//  ProfilePictureRepository.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation
import SwiftData

@MainActor
protocol ProfilePictureRepository {
    func getProfilePicture(byPath path: String) async throws -> ProfilePicture?
    func getAllProfilePictures() async throws -> [ProfilePicture]
    func saveProfilePicture(_ profilePicture: ProfilePicture) async throws
    func deleteProfilePictures(notIncludedInPaths pathsToDelete: [String]) async throws
}

@MainActor
class SwiftDataProfilePictureRepository: ProfilePictureRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func getProfilePicture(byPath path: String) async throws -> ProfilePicture? {
        let descriptor = FetchDescriptor<ProfilePicture>(
            predicate: #Predicate<ProfilePicture> { profilePicture in
                profilePicture.path == path
            }
        )
        let profilePictures = try modelContext.fetch(descriptor)
        return profilePictures.first
    }

    func getAllProfilePictures() async throws -> [ProfilePicture] {
        let descriptor = FetchDescriptor<ProfilePicture>()
        let profilePictures = try modelContext.fetch(descriptor)
        return profilePictures
    }

    func saveProfilePicture(_ profilePicture: ProfilePicture) async throws {
        modelContext.insert(profilePicture)
        try modelContext.save()
    }

    func deleteProfilePictures(notIncludedInPaths pathsToRetain: [String]) async throws {
        try modelContext.delete(
            model: ProfilePicture.self,
            where: #Predicate<ProfilePicture> { profilePicture in
                !pathsToRetain.contains(profilePicture.path)
            })
        try modelContext.save()
    }
}
