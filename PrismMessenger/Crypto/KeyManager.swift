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

enum KeyManagerError: Error {
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
            throw KeyManagerError.fetchingFromKeychainFailed
        }
        return data
    }
    
    
    /// Computes a shared secret between our identity key (in secure enclave) and another public key
    /// Used when receiving a message and need to compute DH2 in passive X3DH
    /// - Parameter remoteKey: The remote party's public key
    /// - Returns: The shared secret data
    func computeSharedSecretWithIdentity(remoteKey: P256.KeyAgreement.PublicKey) throws -> SharedSecret {
        // Get the identity key for key agreement
        let data = try getPrivateKeyData()

        let identityKAPrivateKey = try SecureEnclave.P256.KeyAgreement.PrivateKey.init(dataRepresentation: data)
        
        return try identityKAPrivateKey.sharedSecretFromKeyAgreement(with: remoteKey)
    }
}
