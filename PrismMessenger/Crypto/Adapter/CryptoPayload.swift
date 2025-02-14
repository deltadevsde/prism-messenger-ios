//
//  CryptoPayload.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import CryptoKit
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

extension CryptoPayload {
    func toP256KAPrivateKey() throws -> P256.KeyAgreement.PrivateKey {
        return try P256.KeyAgreement.PrivateKey(rawRepresentation: self.bytes)
    }
    
    func toP256KAPublicKey() throws -> P256.KeyAgreement.PublicKey {
        return try P256.KeyAgreement.PublicKey(compressedRepresentation: self.bytes)
    }
    
    func toP256PrivateKey() throws -> P256.Signing.PrivateKey {
        return try P256.Signing.PrivateKey(rawRepresentation: self.bytes)
    }
    
    func toP256PublicKey() throws -> P256.Signing.PublicKey {
        return try P256.Signing.PublicKey(compressedRepresentation: self.bytes)
    }

    func toP256Signature() throws -> P256.Signing.ECDSASignature {
        return try P256.Signing.ECDSASignature(rawRepresentation: self.bytes)
    }
}

extension P256.KeyAgreement.PublicKey {
    func toCryptoPayload() -> CryptoPayload {
        CryptoPayload(algorithm: .secp256r1, bytes: self.compressedRepresentation)
    }
}

extension P256.KeyAgreement.PrivateKey {
    func toCryptoPayload() -> CryptoPayload {
        CryptoPayload(algorithm: .secp256r1, bytes: self.rawRepresentation)
    }
}

extension P256.Signing.PublicKey {
    func toCryptoPayload() -> CryptoPayload {
        CryptoPayload(algorithm: .secp256r1, bytes: self.compressedRepresentation)
    }
}

extension P256.Signing.PrivateKey {
    func toCryptoPayload() -> CryptoPayload {
        CryptoPayload(algorithm: .secp256r1, bytes: self.rawRepresentation)
    }
}

extension P256.Signing.ECDSASignature {
    func toCryptoPayload() -> CryptoPayload {
        CryptoPayload(algorithm: .secp256r1, bytes: self.rawRepresentation)
    }
}
