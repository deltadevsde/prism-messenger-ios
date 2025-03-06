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
    
    /// The sending chain key.
    private(set) var sendChainKey: Data?
    
    /// The receiving chain key.
    private(set) var recvChainKey: Data?
    
    /// The next message number for the sending chain.
    private(set) var sendMessageNumber: UInt64 = 0
    
    /// The next expected message number for the receiving chain.
    private(set) var recvMessageNumber: UInt64 = 0
    
    /// Message keys for skipped out-of-order messages.
    private var skippedMessageKeys: [UInt64: Data] = [:]
    
    /// The previous sending chain's last message number (for header).
    private(set) var previousSendMessageNumber: UInt64 = 0
    
    /// Our current ephemeral private key for the DH ratchet.
    private(set) var localEphemeral: P256.KeyAgreement.PrivateKey?
    
    /// The remote party's current ephemeral public key.
    private(set) var remoteEphemeral: P256.KeyAgreement.PublicKey?
    
    /// Prekey used to send next message.
    /// TODO: This is very ugly way to handle this through the call stack
    private(set) var prekeyID: UInt64?
    
    // MARK: Codable
    
    // Coding keys for Codable implementation.
    private enum CodingKeys: String, CodingKey {
        case rootKey
        case sendChainKey
        case recvChainKey
        case sendMessageNumber
        case recvMessageNumber
        case skippedMessageKeys
        case previousSendMessageNumber
        case localEphemeralData
        case remoteEphemeralData
        case prekeyID
    }
    
    // Encode to a JSON representation.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(rootKey, forKey: .rootKey)
        try container.encode(sendChainKey, forKey: .sendChainKey)
        try container.encode(recvChainKey, forKey: .recvChainKey)
        try container.encode(sendMessageNumber, forKey: .sendMessageNumber)
        try container.encode(recvMessageNumber, forKey: .recvMessageNumber)
        try container.encode(skippedMessageKeys, forKey: .skippedMessageKeys)
        try container.encode(previousSendMessageNumber, forKey: .previousSendMessageNumber)
        try container.encode(prekeyID, forKey: .prekeyID)
            
        // Convert the keys to their raw representation.
        try container.encode(localEphemeral?.rawRepresentation, forKey: .localEphemeralData)
        try container.encode(remoteEphemeral?.rawRepresentation, forKey: .remoteEphemeralData)
    }
    
    // Decode from a JSON representation.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        rootKey = try container.decode(Data.self, forKey: .rootKey)
        sendChainKey = try container.decode(Data?.self, forKey: .sendChainKey)
        recvChainKey = try container.decode(Data?.self, forKey: .recvChainKey)
        sendMessageNumber = try container.decode(UInt64.self, forKey: .sendMessageNumber)
        recvMessageNumber = try container.decode(UInt64.self, forKey: .recvMessageNumber)
        skippedMessageKeys = try container.decode([UInt64: Data].self, forKey: .skippedMessageKeys)
        previousSendMessageNumber = try container.decode(UInt64.self, forKey: .previousSendMessageNumber)
        prekeyID = try container.decode(UInt64?.self, forKey: .prekeyID)
        
        // Decode the keys from their raw representation
        let localEphemeralData = try container.decode(Data.self, forKey: .localEphemeralData)
        localEphemeral = try P256.KeyAgreement.PrivateKey(rawRepresentation: localEphemeralData)
        
        if let remoteEphemeralData = try container.decode(Data?.self, forKey: .remoteEphemeralData) {
            remoteEphemeral = try P256.KeyAgreement.PublicKey(rawRepresentation: remoteEphemeralData)
        } else {
            remoteEphemeral = nil
        }
    }
    
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
    ///   - remoteEphemeral: The remote party's starting ephemeral public key (if available).
    init(initialRootKey: Data,
         localEphemeral: P256.KeyAgreement.PrivateKey?,
         remoteEphemeral: P256.KeyAgreement.PublicKey?,
         prekeyID: UInt64?
    ) {
        self.rootKey = initialRootKey
        self.localEphemeral = localEphemeral
        self.remoteEphemeral = remoteEphemeral
        self.prekeyID = prekeyID
    }
    
    // MARK: - DH Ratchet Step
    
    /// Performs a DH ratchet step when a new remote ephemeral key is received.
    ///
    /// This updates the root key, resets the receiving chain, caches the previous send chain's
    /// last message number for header purposes, and sets up a new sending chain.
    ///
    /// - Parameter newRemoteEphemeral: The new remote ephemeral public key.
    func performDHRatchet(with newRemoteEphemeral: P256.KeyAgreement.PublicKey) throws {
        // Update remote ephemeral key.
        self.remoteEphemeral = newRemoteEphemeral
        
        // If local ephemeral has not been set yet (the recipient receives no ephemeral key for partner), a DH ratchet is not yet possible because the rootKey is still the shared secret from the initial X3DH handshake
        if localEphemeral == nil {
            return
        }
        
        // Compute DH shared secret using the current local ephemeral key.
        let sharedSecret = try localEphemeral!.sharedSecretFromKeyAgreement(with: newRemoteEphemeral)
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
        if self.localEphemeral == nil {
            self.localEphemeral = P256.KeyAgreement.PrivateKey()
        }
        let localEphemeral = self.localEphemeral!
        
        // If the sending chain is not yet set up, derive it using the remote ephemeral.
        if sendChainKey == nil, let remoteEphemeral = self.remoteEphemeral, let localEphemeral = self.localEphemeral {
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
            oneTimePrekeyID: self.prekeyID
        )
        
        // If using a prekey ID, don't use it again, it was just to establish the chain
        self.prekeyID = nil

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
    ///   - ciphertext: The encrypted ciphertext (including authentication tag)
    ///   - header: The Double Ratchet header
    ///   - nonce: The AES-GCM nonce used for encryption
    /// - Returns: The decrypted plaintext.
    func decrypt(ciphertext: Data, header: DoubleRatchetHeader, nonce: AES.GCM.Nonce) throws -> Data {
        // If the receiving chain key is not yet set up (e.g. first message),
        // derive it using the current remote ephemeral key.
        if self.recvChainKey == nil, let remoteEphemeral = self.remoteEphemeral, let localEphemeral = self.localEphemeral {
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
            return try decryptCiphertext(ciphertext, using: symmetricKey, nonce: nonce)
        }
        
        // Convert the ephemeral key from raw representation
        let headerRemoteEphemeral = try P256.KeyAgreement.PublicKey(rawRepresentation: header.ephemeralKey)
        
        // If the sender's ephemeral key has changed, perform a DH ratchet step.
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
        return try decryptCiphertext(ciphertext, using: symmetricKey, nonce: nonce)
    }
    
    /// Decrypts a received Double Ratchet message.
    ///
    /// This function first checks for a cached message key. If none is found, it advances the receiving chain,
    /// caching skipped keys as needed, and then uses the proper key.
    ///
    /// - Parameter message: The complete double ratchet message.
    /// - Returns: The decrypted plaintext.
    func decrypt(message: DoubleRatchetMessage) throws -> Data {
        return try decrypt(ciphertext: message.ciphertext, header: message.header, nonce: message.nonce)
    }

    
    /// Helper function to decrypt a ciphertext (which includes the authentication tag).
    private func decryptCiphertext(_ ciphertext: Data, using symmetricKey: SymmetricKey, nonce: AES.GCM.Nonce) throws -> Data {
        print("DEBUG: Decrypting ciphertext of length \(ciphertext.count)")
        print("DEBUG: Using nonce: \(Data(nonce).map { String(format: "%02x", $0) }.joined())")
        
        // AES-GCM produces a 16-byte tag; ensure ciphertext is long enough.
        guard ciphertext.count >= 16 else {
            print("DEBUG: Ciphertext too short: \(ciphertext.count)")
            throw DoubleRatchetError.invalidCiphertext(length: ciphertext.count)
        }
       
        // Dump the raw bytes for debugging
        print("DEBUG: Ciphertext raw bytes: \(ciphertext.map { String(format: "%02x", $0) }.joined())")
        
        let ct = ciphertext.prefix(ciphertext.count - 16)
        let tag = ciphertext.suffix(16)
        let sealedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ct, tag: tag)
        
        // Create the full combined format by prepending the nonce
        var combinedData = Data()
        combinedData.append(Data(nonce))  // Add the 12-byte nonce first
        combinedData.append(ciphertext)   // Then add our stored ciphertext+tag
        
        print("DEBUG: Reconstructed combined format: \(combinedData.count) bytes")
        print("DEBUG: Combined data: \(combinedData.map { String(format: "%02x", $0) }.joined())")
        return try AES.GCM.open(sealedBox, using: symmetricKey)
    }
    
    /// Gets the current receive chain key (for external message decryption)
    func getRecvChainKey() throws -> Data {
        guard let chainKey = self.recvChainKey else {
            throw DoubleRatchetError.missingRecvChainKey
        }
        return chainKey
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
