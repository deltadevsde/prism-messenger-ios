//
//  FakeClient.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

/// Client that does not talk with a backend, but simulates responses. For previews and testing.
struct FakeClient {

    let store: InMemoryStore

    let userService: UserService

    init(userService: UserService) {
        self.store = InMemoryStore()
        self.userService = userService
    }
}
