//
//  FakeClient.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

enum FakeClientError: Error {
    case authenticationRequired
}

/// Client that does not talk with a backend, but simulates responses. For previews and testing.
class FakeClient {

    let storeProvider: InMemoryStoreProvider

    let userService: UserService

    init(storeProvider: InMemoryStoreProvider, userService: UserService) {
        self.storeProvider = storeProvider
        self.userService = userService
    }
}
