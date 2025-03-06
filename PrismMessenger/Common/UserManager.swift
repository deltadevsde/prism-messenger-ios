//
//  UserManager.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation
import SwiftData

enum UserError: Error {
    case noUserSelected
    case userNotFound
}

protocol UserManagement {
    func getCurrentUsername() throws -> String
    func selectUser(_ username: String)
    func getUser(username: String) throws -> UserData
    func getAllUsers() throws -> [UserData]
    var currentUsername: String? { get }
}

class UserManager: ObservableObject, UserManagement {
    @Published private(set) var currentUsername: String?
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    @MainActor
    func getCurrentUsername() throws -> String {
        if let username = currentUsername, !username.isEmpty {
            return username
        }
        
        // Fallback to first user in database
        let users = try getAllUsers()
        if let firstUser = users.first {
            currentUsername = firstUser.username
            return firstUser.username
        }
        
        throw UserError.noUserSelected
    }
    
    func selectUser(_ username: String) {
        currentUsername = username
    }
    
    @MainActor
    func getUser(username: String) throws -> UserData {
        let descriptor = FetchDescriptor<UserData>(
            predicate: #Predicate<UserData> { user in
                user.username == username
            }
        )
        
        let users = try modelContext.fetch(descriptor)
        guard let user = users.first else {
            throw UserError.userNotFound
        }
        
        return user
    }
    
    @MainActor
    func getAllUsers() throws -> [UserData] {
        let descriptor = FetchDescriptor<UserData>()
        return try modelContext.fetch(descriptor)
    }
}