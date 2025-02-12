//
//  CryptoPayload.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import CryptoKit
import Foundation
import Security

enum CryptoAlgorithm: String, Codable {
    case ed25519
    case secp256k1
    case secp256r1
}

struct CryptoPayload: Codable {
    var algorithm: CryptoAlgorithm
    var bytes: Data
}

protocol CryptoConvertible {
    func toCryptoPayload() -> CryptoPayload
}

extension CryptoPayload {
    func toP256PrivateKey() throws -> P256.Signing.PrivateKey {
        return try P256.Signing.PrivateKey(derRepresentation: self.bytes)
    }
    
    func toP256PublicKey() throws -> P256.Signing.PublicKey {
        return try P256.Signing.PublicKey(compressedRepresentation: self.bytes)
    }

    func toP256Signature() throws -> P256.Signing.ECDSASignature {
        return try P256.Signing.ECDSASignature(rawRepresentation: self.bytes)
    }
}

extension P256.Signing.PublicKey: CryptoConvertible {
    func toCryptoPayload() -> CryptoPayload {
        CryptoPayload(algorithm: .secp256r1, bytes: self.compressedRepresentation)
    }
}

extension P256.Signing.PrivateKey: CryptoConvertible {
    func toCryptoPayload() -> CryptoPayload {
        CryptoPayload(algorithm: .secp256r1, bytes: self.derRepresentation)
    }
}

extension P256.Signing.ECDSASignature: CryptoConvertible {
    func toCryptoPayload() -> CryptoPayload {
        CryptoPayload(algorithm: .secp256r1, bytes: self.rawRepresentation)
    }
}
