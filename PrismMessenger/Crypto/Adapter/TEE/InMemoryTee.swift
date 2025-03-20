//
//  InMemoryTee.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import CryptoKit
import Foundation

class InMemoryTee: TrustedExecutionEnvironment {

    private lazy var identityKey = P256.Signing.PrivateKey()

    func fetchOrCreateIdentityKey() throws -> P256.Signing.PublicKey {
        return identityKey.publicKey
    }

    func createUserKeys() throws -> UserKeys {
        let signedPrekey = P256.KeyAgreement.PrivateKey()

        guard let signedPrekeySignature = try? identityKey.signature(
                for: signedPrekey.publicKey.x963Representation)
        else {
            throw TeeError.signingFailed
        }

        let prekeys = (0..<10).map { _ in P256.KeyAgreement.PrivateKey() }

        return UserKeys(
            identityKey: identityKey.publicKey,
            signedPrekey: signedPrekey,
            signedPrekeySignature: signedPrekeySignature,
            prekeys: prekeys)
    }

    func requestIdentitySignature(dataToSign: Data) throws -> P256.Signing.ECDSASignature {
        do {
            return try identityKey.signature(for: dataToSign)
        } catch {
            throw TeeError.signingFailed
        }
    }

    func computeSharedSecretWithIdentity(remoteKey: P256.KeyAgreement.PublicKey) throws
        -> SharedSecret
    {
        do {
            return try identityKey.forKA().sharedSecretFromKeyAgreement(with: remoteKey)
        } catch {
            throw TeeError.derivingSharedSecretFailed
        }
    }
}
