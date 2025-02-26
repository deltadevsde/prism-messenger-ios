//
//  KeyManager.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import CryptoKit
import KeychainAccess
import LocalAuthentication
import Security
import Foundation

enum KeyServiceError: Error {
    case fetchingFromKeychainFailed
    case publicKeyDerivationFailed
    case keyConversionFailed
}

class KeyManager {
    private static let serviceTag = "xyz.prism.messenger"
    private static let identityPrivateKeyTag = "xyz.prism.messenger.identityPrivateKey"

    private let keychain: KeychainAccess.Keychain

    init() {
        self.keychain = .init(service: Self.serviceTag)
    }

    func fetchIdentityKeyFromKeychain() async throws -> P256.Signing.PublicKey {
        let data = try getPrivateKeyData()
        let privateKey = try SecureEnclave.P256.Signing.PrivateKey.init(dataRepresentation: data)

        return privateKey.publicKey
    }

    func createIdentityKeyPair() throws -> P256.Signing.PublicKey {
        var error: Unmanaged<CFError>?

        let authenticationContext = LAContext()

        #if targetEnvironment(simulator)
            let accessControlFlags: SecAccessControlCreateFlags = [.privateKeyUsage]
        #else
            let accessControlFlags: SecAccessControlCreateFlags = [
                .privateKeyUsage, .biometryCurrentSet,
            ]
        #endif

        guard
            let accessControl = SecAccessControlCreateWithFlags(
                kCFAllocatorDefault,
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                accessControlFlags,
                &error)
        else {
            throw error!.takeRetainedValue() as Error
        }

        let privateKey = try SecureEnclave.P256.Signing.PrivateKey.init(
            accessControl: accessControl,
            authenticationContext: authenticationContext
        )

        try keychain.set(privateKey.dataRepresentation, key: Self.identityPrivateKeyTag)

        return privateKey.publicKey
    }
    
    func createPrekeys(count: UInt) async throws -> [P256.Signing.PrivateKey] {
        var prekeys: [P256.Signing.PrivateKey] = []
        for _ in 0..<count {
            let prekey = P256.Signing.PrivateKey();
            prekeys.append(prekey)
        }
        return prekeys
    }
    
    func createSignedPrekey() async throws -> (signed_prekey: P256.Signing.PrivateKey, prekey_signature: P256.Signing.ECDSASignature) {
        let signed_prekey_priv = P256.Signing.PrivateKey();
        let prekey_sig = try await requestIdentitySignature(dataToSign: Data(signed_prekey_priv.publicKey.derRepresentation))
        
        return (signed_prekey: signed_prekey_priv, prekey_signature: prekey_sig)
    }
    
    func requestIdentitySignature(dataToSign: Data) async throws -> P256.Signing.ECDSASignature {
        let data = try getPrivateKeyData()
        let privateKey = try SecureEnclave.P256.Signing.PrivateKey(dataRepresentation: data)
        
        return try privateKey.signature(for: dataToSign)
    }
    
    private func getPrivateKeyData() throws -> Data {
        guard let data = try keychain.getData(Self.identityPrivateKeyTag) else {
            throw KeyServiceError.fetchingFromKeychainFailed
        }
        return data
    }
    
    
    /// Performs the X3DH key agreement protocol using the identity key in the secure enclave
    /// This method keeps private key operations inside the KeyManager while allowing X3DH protocol to work
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
    ) async throws -> SymmetricKey {
        // Get the identity key for key agreement
        let data = try getPrivateKeyData()

        let identityKAPrivateKey = try SecureEnclave.P256.KeyAgreement.PrivateKey.init(dataRepresentation: data)
        
        // DH1: between our derived identity key and responder's signed pre-key
        let dh1 = try identityKAPrivateKey.sharedSecretFromKeyAgreement(with: responderSignedPreKey)
        
        // DH2: between our ephemeral key and responder's identity key
        let dh2 = try ephemeralKey.sharedSecretFromKeyAgreement(with: responderIdentity)
        
        // DH3: between our ephemeral key and responder's signed pre-key
        let dh3 = try ephemeralKey.sharedSecretFromKeyAgreement(with: responderSignedPreKey)
        
        // Convert each shared secret to Data and combine
        var combinedSecret = Data()
        combinedSecret.append(dh1.withUnsafeBytes { Data($0) })
        combinedSecret.append(dh2.withUnsafeBytes { Data($0) })
        combinedSecret.append(dh3.withUnsafeBytes { Data($0) })
        
        // Optionally include DH4: between our ephemeral key and responder's one-time pre-key
        if let responderOPK = responderOneTimePreKey {
            let dh4 = try ephemeralKey.sharedSecretFromKeyAgreement(with: responderOPK)
            combinedSecret.append(dh4.withUnsafeBytes { Data($0) })
        }
        
        // Derive the final key via HKDF
        let salt = Data()
        let info = Data("X3DH".utf8)
        let derivedKeyData = hkdf(inputKeyingMaterial: combinedSecret, salt: salt, info: info, outputLength: 32)
        return SymmetricKey(data: derivedKeyData)
    }
}
