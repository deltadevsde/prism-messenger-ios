//
//  FakeClient.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation

enum FakeClientError: Error {
    case authenticationRequired
}

/// Client that does not talk with a backend, but simulates responses. For previews and testing.
class FakeClient: RealTimeCommunication {

    let storeProvider: InMemoryStoreProvider

    let userService: UserService

    @MainActor var currentAccountId: UUID? {
        userService.currentUser?.id
    }

    init(storeProvider: InMemoryStoreProvider, userService: UserService) {
        self.storeProvider = storeProvider
        self.userService = userService
    }

    // MARK: - RealTimeCommunication

    func connect() async {
        // FakeClient doesn't need to connect to a real server
        // This is a no-op for testing purposes
    }

    func disconnect() {
        // FakeClient doesn't need to disconnect from a real server
        // This is a no-op for testing purposes
    }
}
