//
//  X3DHTests.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Testing
import Foundation
import CryptoKit
@testable import PrismMessenger


final class X3DHTests {

    var tee: TrustedExecutionEnvironment!
    var x3dh: X3DH!

    init() {
        tee = InMemoryTee()
        x3dh = X3DH(tee: tee)
    }

    @Test func x3dhKeyAgreement() throws {
        // === Initiator (Alice) Key Generation ===
        let aliceIdentity = try tee.fetchOrCreateIdentityKey().forKA() // Alice's long-term identity key
        let aliceEphemeral = P256.KeyAgreement.PrivateKey() // Alice's ephemeral key

        // === Responder (Bob) Key Generation ===
        let bobIdentity = P256.KeyAgreement.PrivateKey()      // Bob's long-term identity key
        let bobSignedPreKey = P256.KeyAgreement.PrivateKey()  // Bob's signed pre-key (published)
        let bobOneTimePreKey = P256.KeyAgreement.PrivateKey() // Bob's one-time pre-key (published)
        
        // Alice performs X3DH key agreement using Bob's public keys.
        let sharedKeyAlice = try x3dh.performX3DH(
            ephemeralKey: aliceEphemeral,
            responderIdentity: bobIdentity.publicKey,
            responderSignedPreKey: bobSignedPreKey.publicKey,
            responderOneTimePreKey: bobOneTimePreKey.publicKey  // Optional – can be nil
        )
        
        // --- Bob's Perspective ---
        // Bob computes the shared key using his private keys and Alice's public keys.
        let dh1_Bob = try bobSignedPreKey.sharedSecretFromKeyAgreement(with: aliceIdentity)
        let dh2_Bob = try bobIdentity.sharedSecretFromKeyAgreement(with: aliceEphemeral.publicKey)
        let dh3_Bob = try bobSignedPreKey.sharedSecretFromKeyAgreement(with: aliceEphemeral.publicKey)
        
        var combinedBob = Data()
        combinedBob.append(dh1_Bob.withUnsafeBytes { Data($0) })
        combinedBob.append(dh2_Bob.withUnsafeBytes { Data($0) })
        combinedBob.append(dh3_Bob.withUnsafeBytes { Data($0) })
        
        // Include DH4 for the one-time pre-key.
        let dh4_Bob = try bobOneTimePreKey.sharedSecretFromKeyAgreement(with: aliceEphemeral.publicKey)
        combinedBob.append(dh4_Bob.withUnsafeBytes { Data($0) })
        
        let derivedBob = hkdf(inputKeyingMaterial: combinedBob,
                              salt: Data(),
                              info: Data("X3DH".utf8),
                              outputLength: 32)
        let sharedKeyBob = SymmetricKey(data: derivedBob)
        
        // Convert keys to Data for comparison.
        let aliceKeyData = sharedKeyAlice.withUnsafeBytes { Data($0) }
        let bobKeyData   = sharedKeyBob.withUnsafeBytes { Data($0) }
        
        // Assert that both parties derive the same shared key.
        #expect(aliceKeyData == bobKeyData, "The shared keys must be equal.")
    }
    
    @Test func x3dhWithoutOneTimePrekey() throws {
        // === Initiator (Alice) Key Generation ===
        let aliceIdentity = try tee.fetchOrCreateIdentityKey().forKA() // Alice's long-term identity key
        let aliceEphemeral = P256.KeyAgreement.PrivateKey() // Alice's ephemeral key

        // === Responder (Bob) Key Generation ===
        let bobIdentity = P256.KeyAgreement.PrivateKey()     // Bob's long-term identity key
        let bobSignedPreKey = P256.KeyAgreement.PrivateKey() // Bob's signed pre-key (published)

        // Alice performs X3DH key agreement using Bob's public keys.
        let sharedKeyAlice = try x3dh.performX3DH(
            ephemeralKey: aliceEphemeral,
            responderIdentity: bobIdentity.publicKey,
            responderSignedPreKey: bobSignedPreKey.publicKey,
            responderOneTimePreKey: nil
        )
        
        // --- Bob's Perspective ---
        // Bob computes the shared key using his private keys and Alice's public keys.
        let dh1_Bob = try bobSignedPreKey.sharedSecretFromKeyAgreement(with: aliceIdentity)
        let dh2_Bob = try bobIdentity.sharedSecretFromKeyAgreement(with: aliceEphemeral.publicKey)
        let dh3_Bob = try bobSignedPreKey.sharedSecretFromKeyAgreement(with: aliceEphemeral.publicKey)
        
        var combinedBob = Data()
        combinedBob.append(dh1_Bob.withUnsafeBytes { Data($0) })
        combinedBob.append(dh2_Bob.withUnsafeBytes { Data($0) })
        combinedBob.append(dh3_Bob.withUnsafeBytes { Data($0) })
        
        let derivedBob = hkdf(inputKeyingMaterial: combinedBob,
                              salt: Data(),
                              info: Data("X3DH".utf8),
                              outputLength: 32)
        let sharedKeyBob = SymmetricKey(data: derivedBob)
        
        // Convert keys to Data for comparison.
        let aliceKeyData = sharedKeyAlice.withUnsafeBytes { Data($0) }
        let bobKeyData   = sharedKeyBob.withUnsafeBytes { Data($0) }
        
        // Assert that both parties derive the same shared key.
        #expect(aliceKeyData == bobKeyData, "The shared keys must be equal.")
    }
}
