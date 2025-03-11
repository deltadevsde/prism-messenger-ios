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
    func initialize() async throws -> Bool {
        // Check if we have any existing users in the database
        let users = try await userRepository.getAllUsers()
        
        if users.isEmpty {
            // No registered users
            return false
        } else {
            // Select the first user
            selectedUsername = users[0].username
            return true
        }
    }
    
    @MainActor
    func selectAccount(username: String) {
        selectedUsername = username
    }
    
    @MainActor
    func setRegistered(username: String) {
        selectedUsername = username
    }
    
    @MainActor
    func getAllUsers() async throws -> [User] {
        return try await userRepository.getAllUsers()
    }
    
    @MainActor
    func getCurrentUser() async throws -> User? {
        guard let username = selectedUsername else {
            return nil
        }
        
        return try await userRepository.getUser(byUsername: username)
    }
}
