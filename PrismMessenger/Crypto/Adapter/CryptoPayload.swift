//
//  CryptoPayload.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Security
import Foundation

enum CryptoAlgorithm: String, Codable {
    case ed25519
    case secp256k1
    case secp256r1
}

struct CryptoPayload: Codable {
    var algorithm: CryptoAlgorithm
    var bytes: Data
}
