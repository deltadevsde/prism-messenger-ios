//
//  P256+Codable.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import CryptoKit

extension P256.Signing.PublicKey: Codable {
    public func encode(to encoder: Encoder) throws {
        try self.toCryptoPayload().encode(to: encoder)
    }

    public init(from decoder: Decoder) throws {
        let payload = try CryptoPayload(from: decoder)
        self = try payload.toP256PublicKey()
    }
}

extension P256.Signing.PrivateKey: Codable {
    public func encode(to encoder: Encoder) throws {
        try self.toCryptoPayload().encode(to: encoder)
    }

    public init(from decoder: Decoder) throws {
        let payload = try CryptoPayload(from: decoder)
        self = try payload.toP256PrivateKey()
    }
}

extension P256.Signing.ECDSASignature: Codable {
    public func encode(to encoder: Encoder) throws {
        try self.toCryptoPayload().encode(to: encoder)
    }

    public init(from decoder: Decoder) throws {
        let payload = try CryptoPayload(from: decoder)
        self = try payload.toP256Signature()
    }
}

extension P256.KeyAgreement.PublicKey: Codable {
    public func encode(to encoder: Encoder) throws {
        try self.toCryptoPayload().encode(to: encoder)
    }

    public init(from decoder: Decoder) throws {
        let payload = try CryptoPayload(from: decoder)
        self = try payload.toP256KAPublicKey()
    }
}

extension P256.KeyAgreement.PrivateKey: Codable {
    public func encode(to encoder: Encoder) throws {
        try self.toCryptoPayload().encode(to: encoder)
    }

    public init(from decoder: Decoder) throws {
        let payload = try CryptoPayload(from: decoder)
        self = try payload.toP256KAPrivateKey()
    }
}
