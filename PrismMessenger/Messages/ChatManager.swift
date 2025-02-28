//
//  ChatManager.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation
import SwiftData
import CryptoKit

class ChatManager {
    private let modelContext: ModelContext
    weak var appLaunch: AppLaunch?
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    /// Creates a new chat from an X3DH handshake and stores it in SwiftData
    /// - Parameters:
    ///   - username: The participant's username
    ///   - sharedSecret: The shared secret derived from X3DH
    ///   - ephemeralPublicKey: The ephemeral public key used in X3DH
    ///   - usedPrekeyId: The ID of the prekey that was used
    /// - Returns: The created ChatData object
    @MainActor
    func createChat(
        username: String,
        sharedSecret: SymmetricKey,
        ephemeralPublicKey: P256.KeyAgreement.PublicKey,
        usedPrekeyId: UInt64?
    ) throws -> ChatData {
        // 0. Get the current user
        let currentUsername = try getCurrentUsername()
        
        // 1. Create a Double Ratchet session with the shared secret
        let session = try createDoubleRatchetSession(
            sharedSecret: sharedSecret,
            ephemeralPublicKey: ephemeralPublicKey,
            oneTimePrekeyId: usedPrekeyId
        )
        
        // 2. Serialize the session
        let sessionData = try serializeDoubleRatchetSession(session)
        let jsonStr = String(data: sessionData, encoding: .utf8)!
        print("sessionData from sender: \(jsonStr)")

        // 3. Create and save the chat
        let chat = ChatData(
            participantUsername: username,
            ownerUsername: currentUsername,
            displayName: username, // Default to username for display until we get more info
            doubleRatchetSession: sessionData
        )
        
        // 4. Add to SwiftData
        modelContext.insert(chat)
        
        // 5. Create a welcome message
        let welcomeMessage = MessageData(
            content: "Chat established securely",
            isFromMe: true,
            status: .sent
        )
        welcomeMessage.chat = chat
        chat.addMessage(welcomeMessage)
        
        try modelContext.save()
        
        return chat
    }
    
    /// Retrieves a chat with a specific participant for the current user, if it exists
    /// - Parameter username: The participant's username
    /// - Returns: The ChatData object if found, nil otherwise
    @MainActor
    func getChat(with username: String) throws -> ChatData? {
        let currentUsername = try getCurrentUsername()
        
        let descriptor = FetchDescriptor<ChatData>(
            predicate: #Predicate { 
                $0.participantUsername == username && 
                $0.ownerUsername == currentUsername 
            }
        )
        let chats = try modelContext.fetch(descriptor)
        return chats.first
    }
    
    /// Gets a list of all chats for the current user, sorted by last message timestamp
    /// - Returns: Array of all chats owned by the current user
    @MainActor
    func getAllChats() throws -> [ChatData] {
        let currentUsername = try getCurrentUsername()
        
        let descriptor = FetchDescriptor<ChatData>(
            predicate: #Predicate { $0.ownerUsername == currentUsername },
            sortBy: [SortDescriptor(\.lastMessageTimestamp, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    /// Creates a DoubleRatchetSession from the shared secret from X3DH
    private func createDoubleRatchetSession(
        sharedSecret: SymmetricKey,
        ephemeralPublicKey: P256.KeyAgreement.PublicKey,
        oneTimePrekeyId: UInt64?
    ) throws -> DoubleRatchetSession {
        // Convert SymmetricKey to Data
        let rootKeyData = sharedSecret.withUnsafeBytes { Data($0) }
        
        // Create a fresh local ephemeral key for the Double Ratchet
        let localEphemeral = P256.KeyAgreement.PrivateKey()
        
        // Initialize the Double Ratchet session
        return DoubleRatchetSession(
            initialRootKey: rootKeyData,
            localEphemeral: localEphemeral,
            remoteEphemeral: ephemeralPublicKey
        )
    }
    
    /// Serializes a DoubleRatchetSession to Data
    private func serializeDoubleRatchetSession(_ session: DoubleRatchetSession) throws -> Data {
        let encoder = JSONEncoder()
        return try encoder.encode(session)
    }
    
    /// Deserializes Data back to a DoubleRatchetSession
    func deserializeDoubleRatchetSession(from data: Data) throws -> DoubleRatchetSession {
        let decoder = JSONDecoder()
        return try decoder.decode(DoubleRatchetSession.self, from: data)
    }
    
    /// Creates a new chat from an incoming message using X3DH passive mode
    /// - Parameters:
    ///   - senderUsername: The username of the message sender
    ///   - senderIdentityKey: The sender's identity key from their KeyBundle
    ///   - senderEphemeralKey: The sender's ephemeral key from the message header
    ///   - usedPrekeyId: The ID of our prekey that was used (if any)
    ///   - keyManager: The KeyManager to perform secure cryptographic operations
    /// - Returns: The newly created ChatData
    @MainActor
    func createChatFromIncomingMessage(
        senderUsername: String,
        senderIdentityKey: P256.KeyAgreement.PublicKey,
        senderEphemeralKey: P256.KeyAgreement.PublicKey,
        usedPrekeyId: UInt64?,
        keyManager: KeyManager
    ) async throws -> ChatData {
        // 1. Get the current user's data
        let currentUsername = try getCurrentUsername()
        let descriptor = FetchDescriptor<UserData>(
            predicate: #Predicate<UserData> { $0.username == currentUsername }
        )
        guard let userData = try modelContext.fetch(descriptor).first else {
            throw MessageError.unauthorized
        }
        
        // 2. Get our signed prekey
        let signedPrekey = try userData.signedPrekey.toP256KAPrivateKey()
        
        // 3. Get the one-time prekey if it was used
        var prekeyKA: P256.KeyAgreement.PrivateKey? = nil
        if let prekeyId = usedPrekeyId, let prekey = try userData.getPrekey(keyIdx: prekeyId) {
            prekeyKA = try P256.KeyAgreement.PrivateKey(rawRepresentation: prekey.rawRepresentation)
            // Mark the prekey as used
            userData.deletePrekey(keyIdx: prekeyId)
        }
        
        // 4. Compute the X3DH shared secret (from receiver's perspective)
        let x3dh = X3DH(keyManager: keyManager)
        let symmetricKey = try await x3dh.performPassiveX3DH(senderEphemeralKey: senderEphemeralKey, senderIdentityKey: senderIdentityKey, receiverSignedPreKey: signedPrekey, receiverOneTimePreKey: prekeyKA)
        
        // 5. Create a Double Ratchet session with the shared secret
        let session = try createDoubleRatchetSession(
            sharedSecret: symmetricKey,
            ephemeralPublicKey: senderEphemeralKey,
            oneTimePrekeyId: usedPrekeyId
        )
        
        // 6. Serialize the session
        let sessionData = try serializeDoubleRatchetSession(session)
        let jsonStr = String(data: sessionData, encoding: .utf8)!
        print("sessionData from recv: \(jsonStr)")
        
        // 7. Create and save the chat
        let chat = ChatData(
            participantUsername: senderUsername,
            ownerUsername: currentUsername,
            displayName: senderUsername, // Default to username for display
            doubleRatchetSession: sessionData
        )
        
        // 8. Add to SwiftData
        modelContext.insert(chat)
        
        // 9. Create a welcome message
        let welcomeMessage = MessageData(
            content: "Chat established securely",
            isFromMe: false,
            status: .delivered
        )
        welcomeMessage.chat = chat
        chat.addMessage(welcomeMessage)
        
        // 10. Add a system message indicating how the chat was created
        let systemMessage = MessageData(
            content: "\(senderUsername) started this conversation",
            isFromMe: false,
            status: .delivered
        )
        systemMessage.chat = chat
        chat.addMessage(systemMessage)
        
        try modelContext.save()
        
        return chat
    }
    
    /// Sends a message in a chat
    /// - Parameters:
    ///   - content: The message content
    ///   - chat: The chat to send the message in
    ///   - messageService: Optional MessageService to send the message to the server
    /// - Returns: The created MessageData object
    func sendMessage(
        content: String, 
        in chat: ChatData,
        messageService: MessageService? = nil
    ) async throws -> MessageData {
        // 1. Deserialize the Double Ratchet session
        let session = try deserializeDoubleRatchetSession(from: chat.doubleRatchetSession)
        
        // 2. Encrypt the message content
        let contentData = Data(content.utf8)
        let encryptedMessage = try session.encrypt(plaintext: contentData)
        
        // 3. Create the message with initial status of sending
        let message = MessageData(
            content: content,
            isFromMe: true,
            status: .sending
        )
        message.chat = chat
        chat.addMessage(message)
        
        // 4. Re-serialize the updated session state after encryption
        chat.doubleRatchetSession = try serializeDoubleRatchetSession(session)
        
        // Save initial state with "sending" status
        try modelContext.save()
        
        // 5. Send the encrypted message to the server if a MessageService is provided
        if let messageService = messageService {
            do {
                // Get username from a userData context (this would come from your app's auth context)
                let selfUserName = try await MainActor.run { try self.getCurrentUsername() }
                
                // Send message to server
                let response = try await messageService.sendMessage(
                    encryptedMessage,
                    from: selfUserName,
                    to: chat.participantUsername
                )
                
                // Update message status to "sent" after server confirms receipt
                message.status = .sent
                message.serverId = response.message_id
                message.serverTimestamp = Date(timeIntervalSince1970: TimeInterval(response.timestamp) / 1000)
                
                try modelContext.save()
            } catch {
                // If sending fails, mark message as failed
                message.status = .failed
                try modelContext.save()
                throw error
            }
        }
        
        return message
    }
    
    /// Receive and process an incoming message
    /// - Parameters:
    ///   - drMessage: The encrypted DoubleRatchetMessage
    ///   - chat: The chat this message belongs to
    ///   - sender: The sender's username
    /// - Returns: The created MessageData object if successful
    func receiveMessage(
        _ drMessage: DoubleRatchetMessage,
        in chat: ChatData,
        from sender: String
    ) async throws -> MessageData? {
        print("DEBUG: Receiving message in chat with \(sender)")
        do {
            // 1. Deserialize the Double Ratchet session
            print("DEBUG: Deserializing Double Ratchet session from \(chat.doubleRatchetSession.count) bytes")
            let session = try deserializeDoubleRatchetSession(from: chat.doubleRatchetSession)
            print("DEBUG: Successfully deserialized session")
            
            // 2. Decrypt the message content
            print("DEBUG: About to decrypt message")
            print("DEBUG: Ciphertext size: \(drMessage.ciphertext.count) bytes")
            print("DEBUG: Nonce size: \(Data(drMessage.nonce).count) bytes")
            
            // Try multiple decryption approaches due to potential format issues
            let decryptedData: Data
            
            do {
                // Method 1: Use decrypt function with message
                decryptedData = try session.decrypt(message: drMessage)
                print("DEBUG: Successfully decrypted message using method 1")
            } catch let error1 {
                print("DEBUG: Method 1 failed: \(error1)")
                throw error1
            }
        
        // 3. Convert decrypted data to a string
        guard let content = String(data: decryptedData, encoding: .utf8) else {
            print("DEBUG: Failed to decode string from data")
            throw MessageError.messageDecodingFailed
        }
        print("DEBUG: Decoded message: \(content)")
        
        // 4. Re-serialize the updated session state after decryption
        do {
            chat.doubleRatchetSession = try serializeDoubleRatchetSession(session)
            print("DEBUG: Re-serialized session")
        } catch {
            print("DEBUG: Failed to re-serialize session: \(error)")
            throw error
        }
        
        // 5. Create and save the message
        let message = MessageData(
            content: content,
            isFromMe: false,
            status: .delivered
        )
        message.chat = chat
        chat.addMessage(message)
        
        do {
            try modelContext.save()
            print("DEBUG: Saved message to database")
        } catch {
            print("DEBUG: Failed to save message: \(error)")
            throw error
        }
        
        return message
        } catch {
            print("DEBUG: Error in receiveMessage: \(error)")
            throw error
        }
    }
    
    /// Given a chain key, derive a message key and the next chain key.
    /// Same implementation as in DoubleRatchet.swift
    private func deriveMessageKey(from chainKey: Data) -> (messageKey: Data, newChainKey: Data) {
        let keyMaterial = localHkdf(
            inputKeyingMaterial: chainKey,
            salt: Data(),
            info: Data("DoubleRatchetMessage".utf8),
            outputLength: 64
        )
        let messageKey = keyMaterial.prefix(32)
        let newChainKey = keyMaterial.suffix(32)
        return (Data(messageKey), Data(newChainKey))
    }
    
    // MARK: - Local HKDF Implementation (copy of HKDF.swift)
    
    /// Local implementation of HKDF extract
    private func localHkdfExtract(salt: Data, inputKeyingMaterial ikm: Data) -> Data {
        // If salt is empty, use a salt of HashLen (32 bytes for SHA256) zeros.
        let effectiveSalt = salt.isEmpty ? Data(repeating: 0, count: Int(SHA256.byteCount)) : salt
        let saltKey = SymmetricKey(data: effectiveSalt)
        let prk = HMAC<SHA256>.authenticationCode(for: ikm, using: saltKey)
        return Data(prk)
    }
    
    /// Local implementation of HKDF expand
    private func localHkdfExpand(prk: Data, info: Data, outputLength: Int) -> Data {
        var okm = Data()
        var previousBlock = Data()
        var counter: UInt8 = 1
    
        while okm.count < outputLength {
            var data = Data()
            // T(n) = HMAC(PRK, T(n-1) || info || counter)
            data.append(previousBlock)
            data.append(info)
            data.append(counter)
            
            let prkKey = SymmetricKey(data: prk)
            let block = HMAC<SHA256>.authenticationCode(for: data, using: prkKey)
            previousBlock = Data(block)
            okm.append(previousBlock)
            counter += 1
        }
        
        return okm.prefix(outputLength)
    }
    
    /// Local implementation of HKDF
    private func localHkdf(inputKeyingMaterial ikm: Data, salt: Data, info: Data, outputLength: Int) -> Data {
        let prk = localHkdfExtract(salt: salt, inputKeyingMaterial: ikm)
        let okm = localHkdfExpand(prk: prk, info: info, outputLength: outputLength)
        return okm
    }
    
    /// Get the current user's username from appLaunch
    /// - Returns: The current user's username
    @MainActor
    private func getCurrentUsername() throws -> String {
        if let username = appLaunch?.selectedUsername, !username.isEmpty {
            return username
        }
        
        // Try to get any user from the database
        let descriptor = FetchDescriptor<UserData>()
        let users = try modelContext.fetch(descriptor)
        if let firstUser = users.first {
            return firstUser.username
        }
        throw MessageError.unauthorized
    }
}
