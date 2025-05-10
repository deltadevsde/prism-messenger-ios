//
//  FakeClient+MessageGateway.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation

private struct StoredKeyBundle {
    let accountId: UUID
    let keyBundle: KeyBundle
}

extension FakeClient: KeyGateway {
    func submitKeyBundle(keyBundle: KeyBundle) async throws {
        guard let user = try await userService.getCurrentUser() else {
            throw UserGatewayError.requestFailed(0)
        }

        guard (store.getList(FakeUser.self).contains { $0.id == user.id })
        else {
            throw UserGatewayError.requestFailed(1)
        }

        store.addToList(StoredKeyBundle(accountId: user.id, keyBundle: keyBundle))
    }

    func fetchKeyBundle(for accountId: UUID) async throws -> KeyBundle? {
        (store.getList(StoredKeyBundle.self).first { $0.accountId == accountId })?.keyBundle
    }
}
