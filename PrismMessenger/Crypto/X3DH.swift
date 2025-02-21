//
//  X3DH.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation
import CryptoKit

// MARK: - X3DH Key Agreement

/// Implements the X3DH key agreement. In this (simplified) model:
/// - The initiator (e.g. Alice) has a long-term identity key and a freshly generated ephemeral key.
/// - The responder (e.g. Bob) publishes a long-term identity key, a signed pre-key, and optionally a one-time pre-key.
/// The shared key is derived as:
///   K = HKDF( DH(initiatorIdentity, responderSignedPreKey)
///             || DH(initiatorEphemeral, responderIdentity)
///             || DH(initiatorEphemeral, responderSignedPreKey)
///             [ || DH(initiatorEphemeral, responderOneTimePreKey) ] )
struct X3DH {
    /// Performs the X3DH key agreement from the initiator’s side.
    ///
    /// - Parameters:
    ///   - initiatorIdentity: The initiator’s long-term private key.
    ///   - initiatorEphemeral: The initiator’s ephemeral private key.
    ///   - responderIdentity: The responder’s long-term public key.
    ///   - responderSignedPreKey: The responder’s signed pre-key public key.
    ///   - responderOneTimePreKey: Optionally, the responder’s one-time pre-key public key.
    /// - Returns: A symmetric key derived from the DH outputs.
    static func perform(
        initiatorIdentity: P256.KeyAgreement.PrivateKey,
        initiatorEphemeral: P256.KeyAgreement.PrivateKey,
        responderIdentity: P256.KeyAgreement.PublicKey,
        responderSignedPreKey: P256.KeyAgreement.PublicKey,
        responderOneTimePreKey: P256.KeyAgreement.PublicKey? = nil
    ) throws -> SymmetricKey {
        
        // DH1: between initiator's identity key and responder's signed pre-key.
        let dh1 = try initiatorIdentity.sharedSecretFromKeyAgreement(with: responderSignedPreKey)
        // DH2: between initiator's ephemeral key and responder's identity key.
        let dh2 = try initiatorEphemeral.sharedSecretFromKeyAgreement(with: responderIdentity)
        // DH3: between initiator's ephemeral key and responder's signed pre-key.
        let dh3 = try initiatorEphemeral.sharedSecretFromKeyAgreement(with: responderSignedPreKey)
        
        // Convert each shared secret to Data.
        var combinedSecret = Data()
        combinedSecret.append(dh1.withUnsafeBytes { Data($0) })
        combinedSecret.append(dh2.withUnsafeBytes { Data($0) })
        combinedSecret.append(dh3.withUnsafeBytes { Data($0) })
        
        // Optionally include DH4: between initiator's ephemeral key and responder's one-time pre-key.
        if let responderOPK = responderOneTimePreKey {
            let dh4 = try initiatorEphemeral.sharedSecretFromKeyAgreement(with: responderOPK)
            combinedSecret.append(dh4.withUnsafeBytes { Data($0) })
        }
        
        // Derive the final key via HKDF.
        let salt = Data()
        let info = Data("X3DH".utf8)
        let derivedKeyData = hkdf(inputKeyingMaterial: combinedSecret, salt: salt, info: info, outputLength: 32)
        return SymmetricKey(data: derivedKeyData)
    }
}
