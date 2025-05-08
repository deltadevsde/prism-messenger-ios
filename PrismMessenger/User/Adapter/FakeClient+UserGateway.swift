//
//  FakeClient+UserGateway.swift
//  PrismMessenger
//
//  Copyright u00a9 2025 prism. All rights reserved.
//

import Foundation

struct FakeUser {
    var id: UUID = UUID()
    var username: String
    var authPassword: String
    var apnsToken: Data
}

extension FakeClient: UserGateway {
    func updateApnsToken(_ apnsToken: Data) async throws {

        guard let username = await userService.selectedUsername else {
            throw UserGatewayError.requestFailed(0)
        }

        guard
            var existingUser = store.getList(FakeUser.self).first(where: { $0.username == username }
            )
        else {
            throw UserGatewayError.requestFailed(1)
        }

        existingUser.apnsToken = apnsToken
    }

    func fetchAccountId(for username: String) async throws -> UUID? {
        // Find the user with the given username in the fake store
        if let user = store.getList(FakeUser.self).first(where: { $0.username == username }) {
            return user.id
        }

        // Return nil when username doesn't match any existing user
        return nil
    }
}
