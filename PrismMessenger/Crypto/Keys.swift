//
//  Keys.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation
import CryptoKit

struct PrivatePrekey: Codable {
    var key_idx: UInt64
    var key: CryptoPayload
}

struct Prekey: Codable {
    var key_idx: UInt64
    var key: P256.Signing.PublicKey
    
    func fromPrivatePrekey(_ prekey: PrivatePrekey) throws -> Prekey {
        try Prekey(key_idx: prekey.key_idx, key: prekey.key.toP256PrivateKey().publicKey)
    }
}

struct KeyBundle: Codable {
    var identity_key: P256.Signing.PublicKey
    var signed_prekey: P256.Signing.PublicKey
    var signed_prekey_signature: P256.Signing.ECDSASignature
    var prekeys: [Prekey]
}
