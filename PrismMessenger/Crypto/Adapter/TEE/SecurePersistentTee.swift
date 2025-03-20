//
//  SecurePersistentTee.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import CryptoKit
import Foundation
import KeychainAccess
import LocalAuthentication
import Security

/// Implementation of a TEE that uses SecureEnclave to keep the private identity key save.
/// Uses Keychain to persist data that can be used to re-create the private key in SecureEnclave.
class SecurePersistentTee: TrustedExecutionEnvironment {

    private static let serviceTag = "xyz.prism.messenger"
    private static let identityPrivateKeyTag = "xyz.prism.messenger.identityPrivateKey"

    private let keychain: KeychainAccess.Keychain

    init() {
        self.keychain = .init(service: Self.serviceTag)
    }

    func fetchOrCreateIdentityKey() throws -> P256.Signing.PublicKey {
        return try fetchOrCreateIdentityPrivateKey().publicKey
    }

    func createUserKeys() throws -> UserKeys {
        let identityKey = try fetchOrCreateIdentityPrivateKey()
        let (signedPrekey, signedPrekeySignature) = try createSignedPrekey()
        let prekeys = createPrekeys(count: 10)

        return UserKeys(
            identityKey: identityKey.publicKey,
            signedPrekey: signedPrekey,
            signedPrekeySignature: signedPrekeySignature,
            prekeys: prekeys)
    }

    func requestIdentitySignature(dataToSign: Data) throws -> P256.Signing.ECDSASignature {
        let privateKey = try fetchOrCreateIdentityPrivateKey()

        do {
            return try privateKey.signature(for: dataToSign)
        } catch {
            throw TeeError.signingFailed
        }
    }

    func computeSharedSecretWithIdentity(remoteKey: P256.KeyAgreement.PublicKey) throws
        -> SharedSecret
    {
        // Get the identity key for key agreement
        let identityKey = try fetchOrCreateIdentityPrivateKey().forKA()

        do {
            return try identityKey.sharedSecretFromKeyAgreement(with: remoteKey)
        } catch {
            throw TeeError.keyConversionFailed
        }
    }

    func createPrekeys(count: UInt) -> [P256.KeyAgreement.PrivateKey] {
        return (0..<count).map { _ in P256.KeyAgreement.PrivateKey() }
    }

    func createSignedPrekey() throws -> (
        signedPrekey: P256.KeyAgreement.PrivateKey,
        signedPrekeySignature: P256.Signing.ECDSASignature
    ) {
        let signedPrekey = P256.KeyAgreement.PrivateKey()
        let signedPrekeySignature = try requestIdentitySignature(
            dataToSign: Data(signedPrekey.publicKey.x963Representation))

        return (signedPrekey: signedPrekey, signedPrekeySignature: signedPrekeySignature)
    }

    private func fetchOrCreateIdentityPrivateKey() throws -> SecureEnclave.P256.Signing.PrivateKey {
        return try (loadIdentityKeyFromKeychain() ?? createAndStoreIdentityKey())
    }

    private func loadIdentityKeyFromKeychain() throws -> SecureEnclave.P256.Signing.PrivateKey? {
        do {
            guard let data = try keychain.getData(Self.identityPrivateKeyTag) else {
                return nil
            }

            return try SecureEnclave.P256.Signing.PrivateKey(dataRepresentation: data)
        } catch {
            throw TeeError.fetchingIdentityKeyFailed
        }
    }

    private func createAndStoreIdentityKey() throws -> SecureEnclave.P256.Signing.PrivateKey {
        let identityKey = try createIdentityKey()
        try keychain.set(identityKey.dataRepresentation, key: Self.identityPrivateKeyTag)
        return identityKey
    }

    private func createIdentityKey() throws -> SecureEnclave.P256.Signing.PrivateKey {
        var error: Unmanaged<CFError>?

        let authenticationContext = LAContext()

        #if targetEnvironment(simulator)
            print("CREATING IDENTITY KEY")
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

        return try SecureEnclave.P256.Signing.PrivateKey.init(
            accessControl: accessControl,
            authenticationContext: authenticationContext
        )
    }
}
