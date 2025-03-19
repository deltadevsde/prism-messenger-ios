//
//  Keys.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import CryptoKit
import Foundation

struct Prekey: Codable {
    var keyIdx: UInt64
    var key: P256.KeyAgreement.PublicKey
}

struct KeyBundle: Codable {
    var identityKey: P256.Signing.PublicKey
    var signedPrekey: P256.KeyAgreement.PublicKey
    var signedPrekeySignature: P256.Signing.ECDSASignature
    var prekeys: [Prekey]
}
