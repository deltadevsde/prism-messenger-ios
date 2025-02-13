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

enum KeyServiceError: Error {
    case fetchingFromKeychainFailed
    case publicKeyDerivationFailed
}

class KeyManager {
    private static let serviceTag = "xyz.prism.messenger"
    private static let identityPrivateKeyTag = "xyz.prism.messenger.identityPrivateKey"

    private let keychain: KeychainAccess.Keychain

    init() {
        self.keychain = .init(service: Self.serviceTag)
    }

    func fetchIdentityKeyFromKeychain() async throws -> P256.Signing.PublicKey {
        guard let data = try keychain.getData(Self.identityPrivateKeyTag) else {
            throw KeyServiceError.fetchingFromKeychainFailed
        }

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
        guard let data = try keychain.getData(Self.identityPrivateKeyTag) else {
            throw KeyServiceError.fetchingFromKeychainFailed
        }

        let privateKey = try SecureEnclave.P256.Signing.PrivateKey(dataRepresentation: data)
        
        return try privateKey.signature(for: dataToSign)
    }
}
