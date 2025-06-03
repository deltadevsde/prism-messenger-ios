//
//  FakeClient+KeyGateway.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation

private struct StoredKeyBundle: Identifiable {
    let id: UUID
    let keyBundle: KeyBundle
}

extension FakeClient: KeyGateway {

    private var userStore: InMemoryStore<FakeUser> {
        storeProvider.provideTypedStore()
    }

    private var keyBundleStore: InMemoryStore<StoredKeyBundle> {
        storeProvider.provideTypedStore()
    }

    @MainActor
    func submitKeyBundle(keyBundle: KeyBundle) async throws {
        guard let user = userService.currentUser else {
            throw FakeClientError.authenticationRequired
        }

        guard userStore.get(byId: user.id) != nil else {
            throw UserGatewayError.requestFailed(404)
        }

        keyBundleStore.save(StoredKeyBundle(id: user.id, keyBundle: keyBundle))
    }

    func fetchKeyBundle(for accountId: UUID) async throws -> KeyBundle? {
        keyBundleStore.get(byId: accountId)?.keyBundle
    }
}
