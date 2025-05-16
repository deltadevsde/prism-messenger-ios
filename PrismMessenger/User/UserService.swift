//
//  UserService.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation
import SwiftData

@MainActor
class UserService: ObservableObject {
    @Published private(set) var currentUser: User?

    private let userRepository: UserRepository

    init(userRepository: UserRepository) {
        self.userRepository = userRepository
    }

    func loadUser() async throws {
        currentUser = try await userRepository.getUser()
    }

    func saveUser(_ user: User) async throws {
        currentUser = user
        try await userRepository.saveUser(user)
    }
}
