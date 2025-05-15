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

        guard let user = await userService.currentUser else {
            throw FakeClientError.authenticationRequired
        }

        guard
            var existingUser = store.getList(FakeUser.self).first(where: { $0.id == user.id }
            )
        else {
            throw UserGatewayError.requestFailed(404)
        }

        existingUser.apnsToken = apnsToken
    }
}
