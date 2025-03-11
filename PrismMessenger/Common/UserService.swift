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
    
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    @MainActor
    func initialize() async throws -> Bool {
        // Check if we have any existing users in the database
        let descriptor = FetchDescriptor<User>()
        let users = try modelContext.fetch(descriptor)
        
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
    func getAllUsers() throws -> [User] {
        let descriptor = FetchDescriptor<User>()
        return try modelContext.fetch(descriptor)
    }
    
    @MainActor
    func getCurrentUser() throws -> User? {
        guard let username = selectedUsername else {
            return nil
        }
        
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate<User> { user in
                user.username == username
            }
        )
        
        let users = try modelContext.fetch(descriptor)
        return users.first
    }
}
