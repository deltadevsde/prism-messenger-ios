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
        case accountSelection
        case unregistered
        case ready
        case error
    }
    
    @Published private(set) var state: LoadingState = .loading
    @Published var selectedUsername: String?
    
    func initialize(modelContext: ModelContext) async {
        state = .loading
        do {
            try await Task.sleep(nanoseconds: 1000000000)
            
            // Check if we have any existing users in the database
            let descriptor = FetchDescriptor<UserData>()
            let users = try modelContext.fetch(descriptor)
            
            if users.isEmpty {
                // No registered users, show the onboarding flow
                state = .unregistered
            } else if users.count == 1 {
                // Only one user, automatically select it
                selectedUsername = users[0].username
                state = .ready
            } else {
                // Multiple users, show account selection screen
                state = .accountSelection
            }
        } catch {
            state = .error
        }
    }
    
    func selectAccount(username: String) {
        selectedUsername = username
        state = .ready
    }
    
    func createNewAccount() {
        state = .unregistered
    }
    
    func setRegistered(username: String) {
        selectedUsername = username
        state = .ready
    }
}
