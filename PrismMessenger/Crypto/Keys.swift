//
//  Keys.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import CryptoKit
import Foundation

struct Prekey: Codable {
    var key_idx: UInt64
    var key: P256.KeyAgreement.PublicKey
}

struct KeyBundle: Codable {
    var identity_key: P256.Signing.PublicKey
    var signed_prekey: P256.KeyAgreement.PublicKey
    var signed_prekey_signature: P256.Signing.ECDSASignature
    var prekeys: [Prekey]
}

// MARK: - Preview

extension KeyBundle {
    static func random() throws -> Self {
        let identityKeyPriv = P256.Signing.PrivateKey()

        let signedPrekeyPriv = P256.Signing.PrivateKey()
        let signedPrekeySignature = try identityKeyPriv.signature(for: signedPrekeyPriv.publicKey.derRepresentation)

        let prekeys = Array(repeating: P256.Signing.PrivateKey(), count: 10)
            .enumerated()
            .map { Prekey(key_idx: UInt64($0.offset), key: $0.element.publicKey) }

        return Self(
            identity_key: identityKeyPriv.publicKey,
            signed_prekey: signedPrekeyPriv.publicKey,
            signed_prekey_signature: signedPrekeySignature,
            prekeys: prekeys)
    }
}
