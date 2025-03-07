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
    private var userManager: UserManager?
    
    var selectedUsername: String? {
        userManager?.selectedUsername
    }
    
    func initialize(modelContext: ModelContext, userManager: UserManager) async {
        self.userManager = userManager
        state = .loading
        
        do {
            try await Task.sleep(nanoseconds: 1000000000)
            
            // Use UserManager to check for existing users
            let hasUsers = try await userManager.initialize()
            
            if !hasUsers {
                // No registered users, show the onboarding flow
                state = .unregistered
            } else {
                // UserManager has selected a user
                state = .ready
            }
        } catch {
            state = .error
        }
    }
    
    func selectAccount(username: String) {
        userManager?.selectAccount(username: username)
        state = .ready
    }
    
    func createNewAccount() {
        state = .unregistered
    }
    
    func setRegistered(username: String) {
        userManager?.setRegistered(username: username)
        state = .ready
    }
}
