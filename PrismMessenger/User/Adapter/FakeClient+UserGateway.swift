//
//  FakeClient+UserGateway.swift
//  PrismMessenger
//
//  Copyright u00a9 2025 prism. All rights reserved.
//

import Foundation

struct FakeUser: Identifiable {
    var id: UUID = UUID()
    var username: String
    var authPassword: String
    var apnsToken: Data
}

@MainActor
extension FakeClient: UserGateway {

    private var userStore: InMemoryStore<FakeUser> {
        storeProvider.provideTypedStore()
    }

    func updateApnsToken(_ apnsToken: Data) async throws {

        guard let user = userService.currentUser else {
            throw FakeClientError.authenticationRequired
        }

        guard var existingUser = userStore.get(byId: user.id) else {
            throw UserGatewayError.requestFailed(404)
        }

        existingUser.apnsToken = apnsToken
        userStore.save(existingUser)
    }
}
