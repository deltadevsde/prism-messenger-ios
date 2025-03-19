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
