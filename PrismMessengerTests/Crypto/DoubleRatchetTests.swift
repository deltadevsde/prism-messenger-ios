//
//  DoubleRatchetTests.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import CryptoKit
import Foundation
import Testing

@testable import PrismMessenger


final class DoubleRatchetTests {

    /// Helper: Generate 32 random bytes for an initial root key.
    private func generateInitialRootKey() -> Data {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        precondition(status == errSecSuccess, "Failed to generate random bytes")
        return Data(bytes)
    }

    /// Test that messages sent in order are decrypted correctly.
    @Test func doubleRatchetInOrder() throws {
        let initialRootKey = generateInitialRootKey()

        // Generate ephemeral key pairs using P256.
        let aliceEphemeral = P256.KeyAgreement.PrivateKey()
        let bobEphemeral = P256.KeyAgreement.PrivateKey()

        // Initialize sessions.
        // Alice (sender) uses Bob’s public key as remote ephemeral.
        let aliceSession = DoubleRatchetSession(
            initialRootKey: initialRootKey,
            localEphemeral: aliceEphemeral,
            remoteEphemeral: bobEphemeral.publicKey,
            prekeyID: nil)
        // Bob (receiver) uses Alice’s public key as remote ephemeral.
        let bobSession = DoubleRatchetSession(
            initialRootKey: initialRootKey,
            localEphemeral: bobEphemeral,
            remoteEphemeral: aliceEphemeral.publicKey,
            prekeyID: nil)

        // Alice encrypts the first message.
        let plaintext1 = "Hello Bob, message 1".data(using: .utf8)!
        let message1 = try aliceSession.encrypt(plaintext: plaintext1)

        // Bob decrypts the first message.
        let decrypted1 = try bobSession.decrypt(message: message1)
        #expect(plaintext1 == decrypted1, "In-order message 1 should decrypt correctly")

        // Alice encrypts a second message.
        let plaintext2 = "Hello Bob, message 2".data(using: .utf8)!
        let message2 = try aliceSession.encrypt(plaintext: plaintext2)

        // Bob decrypts the second message.
        let decrypted2 = try bobSession.decrypt(message: message2)
        #expect(plaintext2 == decrypted2, "In-order message 2 should decrypt correctly")
    }

    /// Test that out-of-order messages are handled properly using cached (skipped) message keys.
    @Test func doubleRatchetOutOfOrder() throws {
        let initialRootKey = generateInitialRootKey()

        let aliceEphemeral = P256.KeyAgreement.PrivateKey()
        let bobEphemeral = P256.KeyAgreement.PrivateKey()

        let aliceSession = DoubleRatchetSession(
            initialRootKey: initialRootKey,
            localEphemeral: aliceEphemeral,
            remoteEphemeral: bobEphemeral.publicKey, prekeyID: nil)
        let bobSession = DoubleRatchetSession(
            initialRootKey: initialRootKey,
            localEphemeral: bobEphemeral,
            remoteEphemeral: aliceEphemeral.publicKey, prekeyID: nil)

        // Alice sends three messages.
        let plaintexts: [Data] = [
            "Out-of-order message 1".data(using: .utf8)!,
            "Out-of-order message 2".data(using: .utf8)!,
            "Out-of-order message 3".data(using: .utf8)!,
        ]

        var sentMessages: [DoubleRatchetMessage] = []
        for pt in plaintexts {
            let msg = try aliceSession.encrypt(plaintext: pt)
            sentMessages.append(msg)
        }

        // Bob receives the messages out of order.
        // First, receive the second message.
        let decrypted2 = try bobSession.decrypt(message: sentMessages[1])
        #expect(plaintexts[1] == decrypted2, "Message 2 should decrypt correctly when received first")

        // Then, receive the first message.
        let decrypted1 = try bobSession.decrypt(message: sentMessages[0])
        #expect(plaintexts[0] == decrypted1,
            "Message 1 should decrypt correctly when received out-of-order")

        // Finally, receive the third message.
        let decrypted3 = try bobSession.decrypt(message: sentMessages[2])
        #expect(plaintexts[2] == decrypted3, "Message 3 should decrypt correctly")
    }

    /// Tests that a DH ratchet update on the sender side is handled correctly.
    @Test func multipleDHRatchetUpdates() throws {
        let initialRootKey = generateInitialRootKey()
        let aliceEphemeral = P256.KeyAgreement.PrivateKey()
        let bobEphemeral = P256.KeyAgreement.PrivateKey()

        let aliceSession = DoubleRatchetSession(
            initialRootKey: initialRootKey,
            localEphemeral: aliceEphemeral,
            remoteEphemeral: bobEphemeral.publicKey,
            prekeyID: nil)
        let bobSession = DoubleRatchetSession(
            initialRootKey: initialRootKey,
            localEphemeral: bobEphemeral,
            remoteEphemeral: aliceEphemeral.publicKey,
            prekeyID: nil)

        // First message before the DH ratchet update.
        let plaintext1 = "Message before DH ratchet update".data(using: .utf8)!
        let message1 = try aliceSession.encrypt(plaintext: plaintext1)
        let decrypted1 = try bobSession.decrypt(message: message1)
        #expect(plaintext1 == decrypted1)

        // Force a DH ratchet update (simulate key rotation) using the testing helper.
        try aliceSession.forceRotateLocalEphemeralForTesting()

        // Second message after the DH ratchet update.
        let plaintext2 = "Message after DH ratchet update".data(using: .utf8)!
        let message2 = try aliceSession.encrypt(plaintext: plaintext2)
        let decrypted2 = try bobSession.decrypt(message: message2)
        #expect(plaintext2 == decrypted2)
    }

    /// Tests that if the ciphertext is tampered with, decryption fails.
    @Test func tamperedCiphertext() throws {
        let initialRootKey = generateInitialRootKey()
        let aliceEphemeral = P256.KeyAgreement.PrivateKey()
        let bobEphemeral = P256.KeyAgreement.PrivateKey()

        let aliceSession = DoubleRatchetSession(
            initialRootKey: initialRootKey,
            localEphemeral: aliceEphemeral,
            remoteEphemeral: bobEphemeral.publicKey,
            prekeyID: nil)
        let bobSession = DoubleRatchetSession(
            initialRootKey: initialRootKey,
            localEphemeral: bobEphemeral,
            remoteEphemeral: aliceEphemeral.publicKey,
            prekeyID: nil)

        let plaintext = "Tampered ciphertext test".data(using: .utf8)!
        let encryptedMessage = try aliceSession.encrypt(plaintext: plaintext)

        // Tamper with the ciphertext by flipping one bit.
        var tamperedCiphertext = Data(encryptedMessage.ciphertext)
        tamperedCiphertext.withUnsafeMutableBytes { (pointer: UnsafeMutableRawBufferPointer) in
            // Make sure we have at least one byte.
            guard pointer.count > 0 else { return }
            pointer[0] ^= 0x01  // Flip the first bit of the first byte.
        }

        let tamperedMessage = DoubleRatchetMessage(
            header: encryptedMessage.header, ciphertext: tamperedCiphertext,
            nonce: encryptedMessage.nonce)

        // Decryption should fail if the ciphertext is tampered with.
        #expect(throws: (any Error).self, "Decryption should fail if the ciphertext is tampered with.") {
            try bobSession.decrypt(message: tamperedMessage)
        }
    }

    /// Tests that if the nonce is modified, decryption fails.
    @Test func invalidNonce() throws {
        let initialRootKey = generateInitialRootKey()
        let aliceEphemeral = P256.KeyAgreement.PrivateKey()
        let bobEphemeral = P256.KeyAgreement.PrivateKey()

        let aliceSession = DoubleRatchetSession(
            initialRootKey: initialRootKey,
            localEphemeral: aliceEphemeral,
            remoteEphemeral: bobEphemeral.publicKey,
            prekeyID: nil)
        let bobSession = DoubleRatchetSession(
            initialRootKey: initialRootKey,
            localEphemeral: bobEphemeral,
            remoteEphemeral: aliceEphemeral.publicKey,
            prekeyID: nil)

        let plaintext = "Invalid nonce test".data(using: .utf8)!
        let message = try aliceSession.encrypt(plaintext: plaintext)

        // Modify the nonce.
        var nonceData = message.nonce.withUnsafeBytes { Data($0) }
        nonceData[0] ^= 0x01
        let invalidNonce = try AES.GCM.Nonce(data: nonceData)

        let invalidMessage = DoubleRatchetMessage(
            header: message.header, ciphertext: message.ciphertext, nonce: invalidNonce)

        #expect(throws: (any Error).self, "Decryption should fail if the nonce is incorrect.") {
            try bobSession.decrypt(message: invalidMessage)
        }
    }

    /// Tests that replaying the same message causes decryption to fail.
    @Test func replayMessage() throws {
        let initialRootKey = generateInitialRootKey()
        let aliceEphemeral = P256.KeyAgreement.PrivateKey()
        let bobEphemeral = P256.KeyAgreement.PrivateKey()

        let aliceSession = DoubleRatchetSession(
            initialRootKey: initialRootKey,
            localEphemeral: aliceEphemeral,
            remoteEphemeral: bobEphemeral.publicKey,
            prekeyID: nil)
        let bobSession = DoubleRatchetSession(
            initialRootKey: initialRootKey,
            localEphemeral: bobEphemeral,
            remoteEphemeral: aliceEphemeral.publicKey,
            prekeyID: nil)

        let plaintext = "Replay message test".data(using: .utf8)!
        let message = try aliceSession.encrypt(plaintext: plaintext)

        // First decryption attempt should succeed.
        let decrypted = try bobSession.decrypt(message: message)
        #expect(plaintext == decrypted)

        // Replaying the same message should now fail.
        #expect(throws: (any Error).self, "Replaying a message should fail decryption due to key consumption.") {
            try bobSession.decrypt(message: message)
        }
    }

    /// Tests that tampering with the header causes decryption to fail.
    @Test func tamperedHeader() throws {
        let initialRootKey = generateInitialRootKey()
        let aliceEphemeral = P256.KeyAgreement.PrivateKey()
        let bobEphemeral = P256.KeyAgreement.PrivateKey()

        let aliceSession = DoubleRatchetSession(
            initialRootKey: initialRootKey,
            localEphemeral: aliceEphemeral,
            remoteEphemeral: bobEphemeral.publicKey,
            prekeyID: nil)
        let bobSession = DoubleRatchetSession(
            initialRootKey: initialRootKey,
            localEphemeral: bobEphemeral,
            remoteEphemeral: aliceEphemeral.publicKey,
            prekeyID: nil)

        let plaintext = "Tampered header test".data(using: .utf8)!
        let message = try aliceSession.encrypt(plaintext: plaintext)

        // Tamper with the header's ephemeral key.
        var tamperedEphemeralKeyRepr = Data(message.header.ephemeralKey.compressedRepresentation);
        tamperedEphemeralKeyRepr.withUnsafeMutableBytes {
                (pointer: UnsafeMutableRawBufferPointer) in
                // Make sure we have at least one byte.
                guard pointer.count > 0 else { return }
                pointer[0] ^= 0x01  // Flip the first bit of the first byte.
            }
        let tamperedEphemeralKey = try P256.KeyAgreement.PublicKey(
            compressedRepresentation: tamperedEphemeralKeyRepr
        )

        let tamperedHeader = DoubleRatchetHeader(
            ephemeralKey: tamperedEphemeralKey,
            messageNumber: message.header.messageNumber,
            previousMessageNumber: message.header.previousMessageNumber,
            oneTimePrekeyId: message.header.oneTimePrekeyId
        )

        let tamperedMessage = DoubleRatchetMessage(
            header: tamperedHeader, ciphertext: message.ciphertext, nonce: message.nonce)
        #expect(throws: (any Error).self, "Tampering with the header should cause decryption to fail.") {
            try bobSession.decrypt(message: tamperedMessage)
        }
    }
}
