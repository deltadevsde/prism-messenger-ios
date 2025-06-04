//
//  ProfileRepository.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation
import SwiftData

@MainActor
protocol ProfileRepository {
    func getProfile(byAccountId accountId: UUID) async throws -> Profile?
    func getProfile(byUsername username: String) async throws -> Profile?
    func getAllProfiles() async throws -> [Profile]
    func saveProfile(_ profile: Profile) async throws
    func deleteProfile(_ profile: Profile) async throws
}

@MainActor
class SwiftDataProfileRepository: ProfileRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func getProfile(byAccountId accountId: UUID) async throws -> Profile? {
        let descriptor = FetchDescriptor<Profile>(
            predicate: #Predicate<Profile> { profile in
                profile.accountId == accountId
            }
        )

        let profiles = try modelContext.fetch(descriptor)
        return profiles.first
    }

    func getProfile(byUsername username: String) async throws -> Profile? {
        let descriptor = FetchDescriptor<Profile>(
            predicate: #Predicate<Profile> { profile in
                profile.username == username
            }
        )

        let profiles = try modelContext.fetch(descriptor)
        return profiles.first
    }

    func getAllProfiles() async throws -> [Profile] {
        let descriptor = FetchDescriptor<Profile>()
        let profiles = try modelContext.fetch(descriptor)
        return profiles
    }

    func saveProfile(_ profile: Profile) async throws {
        modelContext.insert(profile)
        try modelContext.save()
    }

    func deleteProfile(_ profile: Profile) async throws {
        modelContext.delete(profile)
        try modelContext.save()
    }
}
