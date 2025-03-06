//
//  AppLaunch.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation
import SwiftData

@MainActor
class AppLaunch: ObservableObject {
    enum LoadingState {
        case loading
        case unregistered
        case ready
        case error
    }
    
    @Published private(set) var state: LoadingState = .loading
    
    func initialize(modelContext: ModelContext, userManager: UserManager) async {
        state = .loading
        do {
            try await Task.sleep(nanoseconds: 1000000000)
            
            // Check if we have any existing users in the database
            let users = try userManager.getAllUsers()
            
            if users.isEmpty {
                state = .unregistered
            } else {
                // Select the first user automatically
                userManager.selectUser(users[0].username)
                state = .ready
            }
        } catch {
            state = .error
        }
    }
    
    func setRegistered() {
        state = .ready
    }
    
    func setUnregistered() {
        state = .unregistered
    }
    
    func setError() {
        state = .error
    }
}
