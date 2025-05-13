//
//  UserService.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation
import SwiftData

class UserService: ObservableObject {
    @MainActor @Published private(set) var selectedUsername: String?

    private let userRepository: UserRepository

    init(userRepository: UserRepository) {
        self.userRepository = userRepository
    }

    @MainActor
    func populateSelectedUser() async throws {
        // Check if we have any existing users in the database
        let users = try await userRepository.getAllUsers()

        guard !users.isEmpty else {
            return
        }

        // Select the first user
        selectAccount(username: users[0].username)
    }

    @MainActor
    func selectAccount(username: String) {
        selectedUsername = username
    }

    @MainActor
    func getCurrentUser() async throws -> User? {
        guard let username = selectedUsername else {
            return nil
        }

        return try await userRepository.getUser(byUsername: username)
    }

    func saveUser(_ user: User) async throws {
        try await userRepository.saveUser(user)
    }
}
