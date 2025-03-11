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
    private var userService: UserService?
    
    var selectedUsername: String? {
        userService?.selectedUsername
    }
    
    func initialize(modelContext: ModelContext, userService: UserService) async {
        self.userService = userService
        state = .loading
        
        do {
            try await Task.sleep(nanoseconds: 1000000000)
            
            // Use UserService to check for existing users
            let hasUsers = try await userService.initialize()
            
            if !hasUsers {
                // No registered users, show the onboarding flow
                state = .unregistered
            } else {
                // UserService has selected a user
                state = .ready
            }
        } catch {
            state = .error
        }
    }
    
    func selectAccount(username: String) {
        userService?.selectAccount(username: username)
        state = .ready
    }
    
    func createNewAccount() {
        state = .unregistered
    }
    
    func setRegistered(username: String) {
        userService?.setRegistered(username: username)
        state = .ready
    }
}
