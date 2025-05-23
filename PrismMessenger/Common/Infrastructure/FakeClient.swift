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
struct FakeClient {

    let store: InMemoryStore

    let userService: UserService

    init(store: InMemoryStore, userService: UserService) {
        self.store = store
        self.userService = userService
    }
}
