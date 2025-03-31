//
//  X3DH.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation
import CryptoKit

private let log = Log.crypto

enum X3DHError: Error {
    case keyConversionFailed
    case missingPrekeys
}

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
    private let tee: TrustedExecutionEnvironment

    init(tee: TrustedExecutionEnvironment) {
        self.tee = tee
    }
    
    /// Initiates the X3DH handshake with a responder using their key bundle
    /// Does not expose any private keys - all key operations happen within the Trusted Execution Environment
    ///
    /// - Parameters:
    ///   - keyBundle: The responder's key bundle containing their identity and prekeys
    ///   - prekeyId: Optional specific prekey to use from the bundle
    /// - Returns: A tuple with the symmetric key and information needed for the initial message
    func initiateHandshake(
        with keyBundle: KeyBundle,
        using prekeyId: UInt64? = nil
    ) throws -> (symmetricKey: SymmetricKey, ephemeralKey: P256.KeyAgreement.PrivateKey, usedPrekeyId: UInt64?) {
        // Generate ephemeral key for this session
        let ephemeralKey = P256.KeyAgreement.PrivateKey()
        
        // Convert responder's signing keys to key agreement keys
        let responderIdentityKA = keyBundle.identityKey.forKA()
        let responderSignedPreKeyKA = keyBundle.signedPrekey

        // Select a one-time prekey if available
        var responderOneTimePreKeyKA: P256.KeyAgreement.PublicKey? = nil
        var usedPrekeyId: UInt64? = nil
        
        if let specificPrekeyId = prekeyId, 
           let selectedPrekey = keyBundle.prekeys.first(where: { $0.keyIdx == specificPrekeyId }) {
            responderOneTimePreKeyKA = selectedPrekey.key
            usedPrekeyId = specificPrekeyId
        }
        
        // Delegate the key agreement calculation to the TEE
        // This keeps the private key operations safely within TEE
        let symmetricKey = try performX3DH(
            ephemeralKey: ephemeralKey,
            responderIdentity: responderIdentityKA,
            responderSignedPreKey: responderSignedPreKeyKA,
            responderOneTimePreKey: responderOneTimePreKeyKA
        )
        
        return (symmetricKey: symmetricKey, ephemeralKey: ephemeralKey, usedPrekeyId: usedPrekeyId)
    }
    
    /// Performs the X3DH key agreement protocol using the identity key in the secure enclave and a received key bundle
    /// This method keeps private key operations inside the TEE while allowing X3DH protocol to work
    ///
    /// - Parameters:
    ///   - senderEphemeralKey: The ephemeral key generated by the sender for this session
    ///   - senderIdentityKey: The sender's identity key
    ///   - receiverSignedPreKey: The recipient's signed prekey (converted to KeyAgreement type)
    ///   - receiverOneTimePreKey: Optional one-time prekey (converted to KeyAgreement type)
    /// - Returns: The symmetric key derived from the X3DH protocol
    func performPassiveX3DH(
        senderEphemeralKey: P256.KeyAgreement.PublicKey,
        senderIdentityKey: P256.KeyAgreement.PublicKey,
        receiverSignedPreKey: P256.KeyAgreement.PrivateKey,
        receiverOneTimePreKey: P256.KeyAgreement.PrivateKey?
    ) throws -> SymmetricKey {
        let dh1 = try receiverSignedPreKey.sharedSecretFromKeyAgreement(with: senderIdentityKey)
        let dh2 = try tee.computeSharedSecretWithIdentity(remoteKey: senderEphemeralKey)
        let dh3 = try receiverSignedPreKey.sharedSecretFromKeyAgreement(with: senderEphemeralKey)
        
        var dh4: SharedSecret? = nil
        if let receiverOPK = receiverOneTimePreKey {
            dh4 = try receiverOPK.sharedSecretFromKeyAgreement(with: senderEphemeralKey)
        }
        
        return try deriveSymmetricKey(dh1: dh1, dh2: dh2, dh3: dh3, dh4: dh4)
        
    }
    
    /// Performs the X3DH key agreement protocol using the identity key in the secure enclave
    /// This method keeps private key operations inside the TEE while allowing X3DH protocol to work
    ///
    /// - Parameters:
    ///   - ephemeralKey: The ephemeral key generated for this session
    ///   - responderIdentity: The responder's identity key (converted to KeyAgreement type)
    ///   - responderSignedPreKey: The responder's signed prekey (converted to KeyAgreement type)
    ///   - responderOneTimePreKey: Optional one-time prekey (converted to KeyAgreement type)
    /// - Returns: The symmetric key derived from the X3DH protocol
    func performX3DH(
        ephemeralKey: P256.KeyAgreement.PrivateKey,
        responderIdentity: P256.KeyAgreement.PublicKey,
        responderSignedPreKey: P256.KeyAgreement.PublicKey,
        responderOneTimePreKey: P256.KeyAgreement.PublicKey? = nil
    ) throws -> SymmetricKey {
        // DH1: between our derived identity key and responder's signed pre-key
        let dh1 = try tee.computeSharedSecretWithIdentity(remoteKey: responderSignedPreKey)

        // DH2: between our ephemeral key and responder's identity key
        let dh2 = try ephemeralKey.sharedSecretFromKeyAgreement(with: responderIdentity)
        
        // DH3: between our ephemeral key and responder's signed pre-key
        let dh3 = try ephemeralKey.sharedSecretFromKeyAgreement(with: responderSignedPreKey)
        
        var dh4: SharedSecret? = nil
        // Optionally include DH4: between our ephemeral key and responder's one-time pre-key
        if let responderOPK = responderOneTimePreKey {
            dh4 = try ephemeralKey.sharedSecretFromKeyAgreement(with: responderOPK)
        }
        
        return try deriveSymmetricKey(dh1: dh1, dh2: dh2, dh3: dh3, dh4: dh4)
    }
    
    private func deriveSymmetricKey(dh1: SharedSecret, dh2: SharedSecret, dh3: SharedSecret, dh4: SharedSecret?) throws -> SymmetricKey {
        var combinedSecret = Data()
        combinedSecret.append(dh1.withUnsafeBytes { Data($0) })
        combinedSecret.append(dh2.withUnsafeBytes { Data($0) })
        combinedSecret.append(dh3.withUnsafeBytes { Data($0) })
        
        if let dhOPK = dh4 {
            log.debug("X3DH: Using DH4: \(dhOPK)")
            combinedSecret.append(dhOPK.withUnsafeBytes { Data($0) })
        } else {
            log.debug("X3DH: Not using DH4")
        }

        // Derive the final key via HKDF
        let salt = Data()
        let info = Data("X3DH".utf8)
        let derivedKeyData = hkdf(inputKeyingMaterial: combinedSecret, salt: salt, info: info, outputLength: 32)
        return SymmetricKey(data: derivedKeyData)
    }
}
