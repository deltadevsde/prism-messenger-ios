//
//  TrustedExecutionEnvironment.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import CryptoKit
import Foundation

/// Errors that can occur during TEE operations
enum TeeError: Error {
    /// Error when attempting to fetch the identity key from secure storage
    case fetchingIdentityKeyFailed
    /// Error when attempting to derive a shared secret during key agreement
    case derivingSharedSecretFailed
    /// Error when attempting to convert between key types or formats
    case keyConversionFailed
    /// Error when attempting to sign data with the identity key
    case signingFailed
}

/// Collection of cryptographic keys required for the X3DH protocol
struct UserKeys {
    /// The long-term identity public key used for signatures and authentication
    let identityKey: P256.Signing.PublicKey
    /// The medium-term signed prekey used for X3DH key agreement
    let signedPrekey: P256.KeyAgreement.PrivateKey
    /// Signature proving the signed prekey is authorized by the identity key
    let signedPrekeySignature: P256.Signing.ECDSASignature
    /// Collection of one-time prekeys used for X3DH key agreement
    let prekeys: [P256.KeyAgreement.PrivateKey]
}

/// Protocol defining secure key management operations
///
/// A Trusted Execution Environment (TEE) is responsible for securely generating,
/// storing, and using cryptographic keys in a way that protects their confidentiality
/// and integrity, even if the main application is compromised.
protocol TrustedExecutionEnvironment {
    
    /// Retrieves the user's long-term identity public key, creating it if it doesn't exist
    ///
    /// The identity key is used for signing and authentication purposes in the X3DH protocol.
    /// This method should securely generate and store the private key if it doesn't exist.
    ///
    /// - Returns: The P256 ECDSA public key for the user's identity
    /// - Throws: `TeeError.fetchingIdentityKeyFailed` if the key cannot be retrieved or created
    func fetchOrCreateIdentityKey() throws -> P256.Signing.PublicKey
    
    /// Creates a complete set of cryptographic keys required for the X3DH protocol
    ///
    /// This includes:
    /// - Identity key (long-term)
    /// - Signed prekey with signature (medium-term)
    /// - One-time prekeys (short-term)
    ///
    /// - Returns: A `UserKeys` structure containing all required keys
    /// - Throws: Various `TeeError` types if key generation or signing fails
    func createUserKeys() throws -> UserKeys
    
    /// Signs arbitrary data using the user's identity key
    ///
    /// - Parameter dataToSign: The data to be signed
    /// - Returns: An ECDSA signature over the provided data
    /// - Throws: `TeeError.signingFailed` if the signing operation fails
    func requestIdentitySignature(dataToSign: Data) throws -> P256.Signing.ECDSASignature
    
    /// Computes a shared secret between the user's identity key and a remote public key
    ///
    /// Used in the X3DH protocol for the DH calculation between the local identity key
    /// and the remote public key.
    ///
    /// - Parameter remoteKey: The remote party's public key for key agreement
    /// - Returns: A shared secret that can be used as input to a KDF
    /// - Throws: `TeeError.derivingSharedSecretFailed` if key agreement fails
    func computeSharedSecretWithIdentity(remoteKey: P256.KeyAgreement.PublicKey) throws -> SharedSecret
}
