//
//  P256+Codable.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import CryptoKit

extension P256.Signing.PublicKey {
    public func forKA() -> P256.KeyAgreement.PublicKey {
        try! .init(rawRepresentation: rawRepresentation)
    }
}

extension P256.Signing.PrivateKey {
    public func forKA() -> P256.KeyAgreement.PrivateKey {
        try! .init(rawRepresentation: rawRepresentation)
    }
}

extension SecureEnclave.P256.Signing.PrivateKey {
    public func forKA() -> SecureEnclave.P256.KeyAgreement.PrivateKey {
        try! .init(dataRepresentation: dataRepresentation)
    }
}
