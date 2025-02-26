//
//  X3DH.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation
import CryptoKit

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
    private let keyManager: KeyManager
    
    init(keyManager: KeyManager) {
        self.keyManager = keyManager
    }
    
    /// Initiates the X3DH handshake with a responder using their key bundle
    /// Does not expose any private keys - all key operations happen within the KeyManager
    ///
    /// - Parameters:
    ///   - keyBundle: The responder's key bundle containing their identity and prekeys
    ///   - prekeyId: Optional specific prekey to use from the bundle
    /// - Returns: A tuple with the symmetric key and information needed for the initial message
    func initiateHandshake(
        with keyBundle: KeyBundle,
        using prekeyId: UInt64? = nil
    ) async throws -> (symmetricKey: SymmetricKey, ephemeralKey: P256.KeyAgreement.PublicKey, usedPrekeyId: UInt64?) {
        // Generate ephemeral key for this session
        let ephemeralKey = P256.KeyAgreement.PrivateKey()
        
        // Convert responder's signing keys to key agreement keys
        let responderIdentityKA = try convertSigningToKeyAgreement(publicKey: keyBundle.identity_key)
        let responderSignedPreKeyKA = try convertSigningToKeyAgreement(publicKey: keyBundle.signed_prekey)
        
        // Select a one-time prekey if available
        var responderOneTimePreKeyKA: P256.KeyAgreement.PublicKey? = nil
        var usedPrekeyId: UInt64? = nil
        
        if let specificPrekeyId = prekeyId, 
           let selectedPrekey = keyBundle.prekeys.first(where: { $0.key_idx == specificPrekeyId }) {
            responderOneTimePreKeyKA = try convertSigningToKeyAgreement(publicKey: selectedPrekey.key)
            usedPrekeyId = specificPrekeyId
        } else if !keyBundle.prekeys.isEmpty {
            // Use first available prekey if none specified
            let prekey = keyBundle.prekeys[0]
            responderOneTimePreKeyKA = try convertSigningToKeyAgreement(publicKey: prekey.key)
            usedPrekeyId = prekey.key_idx
        }
        
        // Delegate the key agreement calculation to the KeyManager
        // This keeps the private key operations safely within KeyManager
        let symmetricKey = try await keyManager.performX3DH(
            ephemeralKey: ephemeralKey,
            responderIdentity: responderIdentityKA,
            responderSignedPreKey: responderSignedPreKeyKA,
            responderOneTimePreKey: responderOneTimePreKeyKA
        )
        
        return (symmetricKey: symmetricKey, ephemeralKey: ephemeralKey.publicKey, usedPrekeyId: usedPrekeyId)
    }
    
    /// Converts a P256.Signing.PublicKey to a P256.KeyAgreement.PublicKey using raw representation
    private func convertSigningToKeyAgreement(publicKey: P256.Signing.PublicKey) throws -> P256.KeyAgreement.PublicKey {
        do {
            return try P256.KeyAgreement.PublicKey(rawRepresentation: publicKey.rawRepresentation)
        } catch {
            throw X3DHError.keyConversionFailed
        }
    }
}