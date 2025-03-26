//
//  FakeClient+MessageGateway.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation

extension FakeClient: KeyGateway {
    func submitKeyBundle(for username: String, keyBundle: KeyBundle) async throws {
    }

    func fetchKeyBundle(for username: String) async throws -> KeyBundle? {
        let userKeys = try InMemoryTee().createUserKeys()
        return KeyBundle(
            identityKey: userKeys.identityKey,
            signedPrekey: userKeys.signedPrekey.publicKey,
            signedPrekeySignature: userKeys.signedPrekeySignature,
            prekeys: userKeys.prekeys
                .enumerated()
                .map { Prekey(keyIdx: UInt64($0.offset), key: $0.element.publicKey) })
    }
}
