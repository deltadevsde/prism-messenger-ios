//
//  FakeClient+MessageGateway.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation

private struct StoredKeyBundle {
    let username: String
    let keyBundle: KeyBundle
}

extension FakeClient: KeyGateway {
    func submitKeyBundle(for username: String, keyBundle: KeyBundle) async throws {
    }

    func fetchKeyBundle(for username: String) async throws -> KeyBundle? {
        let userKeys = try InMemoryTee().createUserKeys()
        return KeyBundle(
            identity_key: userKeys.identityKey,
            signed_prekey: userKeys.signedPrekey.publicKey,
            signed_prekey_signature: userKeys.signedPrekeySignature,
            prekeys: userKeys.prekeys
                .enumerated()
                .map { Prekey(key_idx: UInt64($0.offset), key: $0.element.publicKey) })
    }
}
