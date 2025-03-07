//
//  UserManager.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation
import SwiftData

class UserManager: ObservableObject {
    @MainActor @Published private(set) var selectedUsername: String?
    
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    @MainActor
    func initialize() async throws -> Bool {
        // Check if we have any existing users in the database
        let descriptor = FetchDescriptor<UserData>()
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
    func getAllUsers() throws -> [UserData] {
        let descriptor = FetchDescriptor<UserData>()
        return try modelContext.fetch(descriptor)
    }
    
    @MainActor
    func getCurrentUser() throws -> UserData? {
        guard let username = selectedUsername else {
            return nil
        }
        
        let descriptor = FetchDescriptor<UserData>(
            predicate: #Predicate<UserData> { user in
                user.username == username
            }
        )
        
        let users = try modelContext.fetch(descriptor)
        return users.first
    }
}