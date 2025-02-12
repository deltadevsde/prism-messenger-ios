//
//  DoubleRatchet.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//


import Foundation
import CryptoKit

// MARK: - Ratchet Key Derivation Helpers

/// Given the current root key and a DH shared secret, derive a new root key and a chain key.
/// The output is 64 bytes: first 32 for the new root key and last 32 for the chain key.
func deriveRatchetKeys(rootKey: Data, dhSharedSecret: Data) -> (newRoot: Data, chainKey: Data) {
    let keyMaterial = hkdf(
        inputKeyingMaterial: dhSharedSecret,
        salt: rootKey,
        info: Data("DoubleRatchet".utf8),
        outputLength: 64
    )
    let newRoot = keyMaterial.prefix(32)
    let chainKey = keyMaterial.suffix(32)
    return (Data(newRoot), Data(chainKey))
}

/// Given a chain key, derive a message key and the next chain key.
func deriveMessageKey(from chainKey: Data) -> (messageKey: Data, newChainKey: Data) {
    let keyMaterial = hkdf(
        inputKeyingMaterial: chainKey,
        salt: Data(),
        info: Data("DoubleRatchetMessage".utf8),
        outputLength: 64
    )
    let messageKey = keyMaterial.prefix(32)
    let newChainKey = keyMaterial.suffix(32)
    return (Data(messageKey), Data(newChainKey))
}

// MARK: - Double Ratchet Session

/// A simplified Double Ratchet session that caches skipped (out-of-order) message keys.
final class DoubleRatchetSession: Codable {
    
    // MARK: Session State Properties
    
    /// The evolving root key.
    private(set) var rootKey: Data
    
    /// Sending chain key.
    private(set) var sendChainKey: Data?
    /// Receiving chain key.
    private(set) var recvChainKey: Data?
    
    /// Message number counters.
    private(set) var sendMessageNumber: UInt64 = 0
    private(set) var recvMessageNumber: UInt64 = 0
    
    /// Cache for skipped (derived but not yet used) receiving message keys.
    private var skippedMessageKeys: [UInt64: Data] = [:]
    
    /// Our current local ephemeral key pair.
    private(set) var localEphemeral: P256.KeyAgreement.PrivateKey
    /// The remote party's current ephemeral public key.
    private(set) var remoteEphemeral: P256.KeyAgreement.PublicKey?
    
    /// The last message number from the previous sending chain.
    private(set) var previousSendMessageNumber: UInt64 = 0
    
    // MARK: Errors
    
    enum DoubleRatchetError: Error {
        case missingSendChainKey
        case missingRecvChainKey
        case invalidCiphertext(length: Int)
        case remoteEphemeralNotAvailable
    }

    // MARK: Initialization
    
    /// Initializes a Double Ratchet session.
    ///
    /// - Parameters:
    ///   - initialRootKey: The initial root key (e.g. derived from X3DH).
    ///   - localEphemeral: Your starting ephemeral key pair.
    ///   - remoteEphemeral: The remote party’s starting ephemeral public key (if available).
    init(initialRootKey: Data,
         localEphemeral: P256.KeyAgreement.PrivateKey,
         remoteEphemeral: P256.KeyAgreement.PublicKey?) {
        self.rootKey = initialRootKey
        self.localEphemeral = localEphemeral
        self.remoteEphemeral = remoteEphemeral
    }
    
    // MARK: - DH Ratchet Step
    
    /// Performs a DH ratchet step when a new remote ephemeral key is received.
    ///
    /// This updates the root key, resets the receiving chain, caches the previous send chain’s
    /// last message number for header purposes, and sets up a new sending chain.
    ///
    /// - Parameter newRemoteEphemeral: The new remote ephemeral public key.
    func performDHRatchet(with newRemoteEphemeral: P256.KeyAgreement.PublicKey) throws {
        // Update remote ephemeral key.
        self.remoteEphemeral = newRemoteEphemeral
        
        // Compute DH shared secret using the current local ephemeral key.
        let sharedSecret = try localEphemeral.sharedSecretFromKeyAgreement(with: newRemoteEphemeral)
        let sharedSecretData = sharedSecret.withUnsafeBytes { Data($0) }
        
        // Derive a new root key and the receiving chain key.
        let derivedRecv = deriveRatchetKeys(rootKey: self.rootKey, dhSharedSecret: sharedSecretData)
        self.rootKey = derivedRecv.newRoot
        self.recvChainKey = derivedRecv.chainKey
        self.recvMessageNumber = 0
        
        // Save the current send message number for the header of outgoing messages.
        self.previousSendMessageNumber = self.sendMessageNumber
        
        // Generate a new local ephemeral key.
        let newLocalEphemeral = P256.KeyAgreement.PrivateKey()
        // Derive a new sending chain key using the new local ephemeral key.
        let newSharedSecret = try newLocalEphemeral.sharedSecretFromKeyAgreement(with: newRemoteEphemeral)
        let newSharedSecretData = newSharedSecret.withUnsafeBytes { Data($0) }
        let derivedSend = deriveRatchetKeys(rootKey: self.rootKey, dhSharedSecret: newSharedSecretData)
        self.rootKey = derivedSend.newRoot
        self.sendChainKey = derivedSend.chainKey
        self.sendMessageNumber = 0
        
        self.localEphemeral = newLocalEphemeral
    }
    
    // MARK: - Receiving: Skipped Message Keys
    
    /// Advances the receiving chain up to (but not including) the target message number,
    /// caching each skipped message key.
    ///
    /// - Parameter target: The target message number to skip keys until.
    private func skipRecvMessageKeys(until target: UInt64) throws {
        guard var chainKey = self.recvChainKey else {
            throw DoubleRatchetError.missingRecvChainKey
        }
        while self.recvMessageNumber < target {
            let (mk, newChainKey) = deriveMessageKey(from: chainKey)
            // Cache the message key for the current recvMessageNumber.
            skippedMessageKeys[self.recvMessageNumber] = mk
            chainKey = newChainKey
            self.recvMessageNumber += 1
        }
        self.recvChainKey = chainKey
    }
    
    // MARK: - Encrypt
    
    /// Encrypts a plaintext message.
    ///
    /// - Parameter plaintext: The plaintext data to encrypt.
    /// - Returns: A tuple containing the message header, the ciphertext (with appended tag), and the AES-GCM nonce.
    func encrypt(plaintext: Data) throws -> DoubleRatchetMessage {
        // If the sending chain is not yet set up, derive it using the remote ephemeral.
        if sendChainKey == nil, let remoteEphemeral = self.remoteEphemeral {
            let sharedSecret = try localEphemeral.sharedSecretFromKeyAgreement(with: remoteEphemeral)
            let sharedSecretData = sharedSecret.withUnsafeBytes { Data($0) }
            let derived = deriveRatchetKeys(rootKey: self.rootKey, dhSharedSecret: sharedSecretData)
            self.rootKey = derived.newRoot
            self.sendChainKey = derived.chainKey
            self.sendMessageNumber = 0
        }
        
        guard let chainKey = self.sendChainKey else {
            throw DoubleRatchetError.missingSendChainKey
        }
        
        // Derive the message key for the current sendMessageNumber.
        let (messageKeyData, newChainKey) = deriveMessageKey(from: chainKey)
        self.sendChainKey = newChainKey
        let currentMessageNumber = self.sendMessageNumber
        self.sendMessageNumber += 1
        
        // Construct the header using our local ephemeral public key.
        let header = DoubleRatchetHeader(
            ephemeralKey: localEphemeral.publicKey.rawRepresentation,
            messageNumber: currentMessageNumber,
            previousMessageNumber: self.previousSendMessageNumber,
            oneTimePrekeyID: nil
        )
        
        let symmetricKey = SymmetricKey(data: messageKeyData)
        let nonce = AES.GCM.Nonce()  // Randomly generated nonce.
        let sealedBox = try AES.GCM.seal(plaintext, using: symmetricKey, nonce: nonce)
        // Combine ciphertext and tag.
        let combinedCiphertext = sealedBox.ciphertext + sealedBox.tag
        
        return DoubleRatchetMessage(header: header, ciphertext: combinedCiphertext, nonce: nonce)
    }
    
    // MARK: - Decrypt
    
    /// Decrypts a received Double Ratchet message.
    ///
    /// This function first checks for a cached message key. If none is found, it advances the receiving chain,
    /// caching skipped keys as needed, and then uses the proper key.
    ///
    /// - Parameters:
    ///   - message: The complete double ratchet message.
    ///   - nonce: The AES-GCM nonce used for encryption.
    /// - Returns: The decrypted plaintext.
    func decrypt(message: DoubleRatchetMessage) throws -> Data {
        let header = message.header
        let nonce = message.nonce

        // If the receiving chain key is not yet set up (e.g. first message),
        // derive it using the current remote ephemeral key.
        if self.recvChainKey == nil, let remoteEphemeral = self.remoteEphemeral {
            let sharedSecret = try localEphemeral.sharedSecretFromKeyAgreement(with: remoteEphemeral)
            let sharedSecretData = sharedSecret.withUnsafeBytes { Data($0) }
            let derived = deriveRatchetKeys(rootKey: self.rootKey, dhSharedSecret: sharedSecretData)
            self.rootKey = derived.newRoot
            self.recvChainKey = derived.chainKey
            self.recvMessageNumber = 0
        }
        
        // If we have a cached key from a previous skip, use it.
        if let cachedKey = skippedMessageKeys[header.messageNumber] {
            skippedMessageKeys.removeValue(forKey: header.messageNumber)
            let symmetricKey = SymmetricKey(data: cachedKey)
            return try decryptCiphertext(message.ciphertext, using: symmetricKey, nonce: nonce)
        }
        
        // Convert the header's ephemeral key.
        let headerRemoteEphemeral = try P256.KeyAgreement.PublicKey(rawRepresentation: header.ephemeralKey)
        
        // If the sender’s ephemeral key has changed, perform a DH ratchet step.
        if self.remoteEphemeral == nil || self.remoteEphemeral!.rawRepresentation != headerRemoteEphemeral.rawRepresentation {
            if header.previousMessageNumber > self.recvMessageNumber {
                try skipRecvMessageKeys(until: header.previousMessageNumber)
            }
            try performDHRatchet(with: headerRemoteEphemeral)
        }
        
        // If the message number is ahead, skip (and cache) keys until we reach it.
        if header.messageNumber > self.recvMessageNumber {
            try skipRecvMessageKeys(until: header.messageNumber)
        }
        
        // Now, derive the message key for the current recvMessageNumber.
        guard let currentRecvChain = self.recvChainKey else {
            throw DoubleRatchetError.missingRecvChainKey
        }
        let (messageKey, newChainKey) = deriveMessageKey(from: currentRecvChain)
        self.recvChainKey = newChainKey
        self.recvMessageNumber += 1
        
        let symmetricKey = SymmetricKey(data: messageKey)
        return try decryptCiphertext(message.ciphertext, using: symmetricKey, nonce: nonce)
    }

    
    /// Helper function to decrypt a ciphertext (which includes the authentication tag).
    private func decryptCiphertext(_ ciphertext: Data, using symmetricKey: SymmetricKey, nonce: AES.GCM.Nonce) throws -> Data {
        // AES-GCM produces a 16-byte tag; ensure ciphertext is long enough.
        guard ciphertext.count >= 16 else {
            throw DoubleRatchetError.invalidCiphertext(length: ciphertext.count)
        }
        let ct = ciphertext.prefix(ciphertext.count - 16)
        let tag = ciphertext.suffix(16)
        let sealedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ct, tag: tag)
        return try AES.GCM.open(sealedBox, using: symmetricKey)
    }
    
    /// For testing only: Force a rotation of the local ephemeral key.
    /// This simulates a DH ratchet update on the sender side.
    func forceRotateLocalEphemeralForTesting() throws {
        // Ensure we have a remote ephemeral key to use.
        guard let remoteEphemeral = self.remoteEphemeral else {
            throw DoubleRatchetError.remoteEphemeralNotAvailable
        }
        // Create a new ephemeral key.
        let newLocalEphemeral = P256.KeyAgreement.PrivateKey()
        // Derive a new sending chain key using the new local ephemeral key.
        let sharedSecret = try newLocalEphemeral.sharedSecretFromKeyAgreement(with: remoteEphemeral)
        let sharedSecretData = sharedSecret.withUnsafeBytes { Data($0) }
        let derived = deriveRatchetKeys(rootKey: self.rootKey, dhSharedSecret: sharedSecretData)
        self.rootKey = derived.newRoot
        self.sendChainKey = derived.chainKey
        self.sendMessageNumber = 0
        
        // Update the local ephemeral key.
        self.localEphemeral = newLocalEphemeral
    }

}
