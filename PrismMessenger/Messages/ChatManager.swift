//
//  ChatManager.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation
import SwiftData
import CryptoKit

enum ChatManagerError: Error {
    case noCurrentUser
    case otherUserNotFound
    case keyExchangeFailed
    case missingKeyBundle
    case missingPreKeys
    case networkFailure(Int)
}

class ChatManager: ObservableObject {
    private let chatRepository: ChatRepository
    private let userService: UserService
    private let messageGateway: MessageGateway
    private let keyGateway: KeyGateway
    private let x3dh: X3DH
    
    init(chatRepository: ChatRepository,
         userService: UserService, 
         messageGateway: MessageGateway,
         keyGateway: KeyGateway,
         x3dh: X3DH) {
        self.chatRepository = chatRepository
        self.userService = userService
        self.messageGateway = messageGateway
        self.keyGateway = keyGateway
        self.x3dh = x3dh
    }
    
    func startChat(with otherUsername: String) async throws -> Chat {
        do {
            // If a chat with this user already exists, reuse it
            if let existingChat = try await getChat(with: otherUsername) {
                return existingChat
            }
            
            // Try to get the key bundle from the other user
            guard
                let keyBundle = try await keyGateway.fetchKeyBundle(for: otherUsername) else {
                throw ChatManagerError.missingKeyBundle
            }
            
            guard let prekey = keyBundle.prekeys.first else {
                throw ChatManagerError.missingPreKeys
            }
            
            // Perform the X3DH handshake
            let (sharedSecret, ephemeralPrivateKey, usedPrekeyId) = try await x3dh.initiateHandshake(with: keyBundle, using: prekey.key_idx)
            
            print("Successfully performed X3DH handshake with user: \(otherUsername)")
            print("Used prekey ID: \(String(describing: usedPrekeyId))")
            
            // Create a new chat with the Double Ratchet session
            return try await createChat(with: otherUsername,
                sharedSecret: sharedSecret,
                ephemeralPrivateKey: ephemeralPrivateKey,
                prekey: prekey
            )
            
        } catch KeyGatewayError.requestFailed(let statusCode) {
            throw ChatManagerError.networkFailure(statusCode)
        }  catch KeyGatewayError.userNotFound {
            throw ChatManagerError.otherUserNotFound
        }  catch is X3DHError {
            throw ChatManagerError.keyExchangeFailed
        }
    }
    
    /// Creates a new chat from an X3DH handshake and stores it in the repository
    /// - Parameters:
    ///   - username: The participant's username
    ///   - sharedSecret: The shared secret derived from X3DH
    ///   - ephemeralPublicKey: The ephemeral public key used in X3DH
    ///   - prekey: The prekey that was used
    /// - Returns: The created Chat object
    @MainActor
    func createChat(
        with otherUsername: String,
        sharedSecret: SymmetricKey,
        ephemeralPrivateKey: P256.KeyAgreement.PrivateKey,
        prekey: Prekey
    ) async throws -> Chat {
        // 0. Get the current user
        let currentUsername = try await getCurrentUsername()
        
        // 1. Create a Double Ratchet session with the shared secret
        let session = try createDoubleRatchetSession(
            sharedSecret: sharedSecret,
            localEphemeral: ephemeralPrivateKey,
            remoteEphemeral: P256.KeyAgreement.PublicKey(rawRepresentation: prekey.key.rawRepresentation),
            prekeyID: prekey.key_idx
        )
        
        // 2. Serialize the session
        let sessionData = try serializeDoubleRatchetSession(session)
        let jsonStr = String(data: sessionData, encoding: .utf8)!
        print("sessionData from sender: \(jsonStr)")

        // 3. Create and save the chat
        let chat = Chat(
            participantUsername: otherUsername,
            ownerUsername: currentUsername,
            displayName: otherUsername, // Default to username for display until we get more info
            doubleRatchetSession: sessionData
        )
        
        // 4. Create a welcome message
        let welcomeMessage = Message(
            content: "Chat established securely",
            isFromMe: true,
            status: .sent
        )
        welcomeMessage.chat = chat
        chat.addMessage(welcomeMessage)
        
        try await chatRepository.saveChat(chat)
        
        return chat
    }
    
    /// Retrieves a chat with a specific participant for the current user, if it exists
    /// - Parameter username: The participant's username
    /// - Returns: The Chat object if found, nil otherwise
    @MainActor
    func getChat(with username: String) async throws -> Chat? {
        let currentUsername = try await getCurrentUsername()
        return try await chatRepository.getChat(withParticipant: username, forOwner: currentUsername)
    }
    
    /// Gets a list of all chats for the current user, sorted by last message timestamp
    /// - Returns: Array of all chats owned by the current user
    @MainActor
    func getAllChats() async throws -> [Chat] {
        let currentUsername = try await getCurrentUsername()
        return try await chatRepository.getAllChats(for: currentUsername)
    }
    
    /// Creates a DoubleRatchetSession from the shared secret from X3DH
    private func createDoubleRatchetSession(
        sharedSecret: SymmetricKey,
        localEphemeral: P256.KeyAgreement.PrivateKey?,
    remoteEphemeral: P256.KeyAgreement.PublicKey?,
        prekeyID: UInt64?
    ) throws -> DoubleRatchetSession {
        // Convert SymmetricKey to Data
        let rootKeyData = sharedSecret.withUnsafeBytes { Data($0) }
        
        // Initialize the Double Ratchet session
        return DoubleRatchetSession(
            initialRootKey: rootKeyData,
            localEphemeral: localEphemeral,
            remoteEphemeral: remoteEphemeral,
            prekeyID: prekeyID
        )
    }
    
    /// Serializes a DoubleRatchetSession to Data
    private func serializeDoubleRatchetSession(_ session: DoubleRatchetSession) throws -> Data {
        let encoder = JSONEncoder()
        return try encoder.encode(session)
    }
    
    /// Deserializes Data back to a DoubleRatchetSession
    private func deserializeDoubleRatchetSession(from data: Data) throws -> DoubleRatchetSession {
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
    ///   - userRepository: The user repository to retrieve the current user data
    /// - Returns: The newly created Chat
    @MainActor
    func createChatFromIncomingMessage(
        senderUsername: String,
        senderIdentityKey: P256.KeyAgreement.PublicKey,
        senderEphemeralKey: P256.KeyAgreement.PublicKey,
        usedPrekeyId: UInt64?
    ) async throws -> Chat {
        // 1. Get the current user's data
        guard let user = try await userService.getCurrentUser() else {
            throw ChatManagerError.noCurrentUser
        }
        
        // 2. Get our signed prekey
        let signedPrekey = try user.signedPrekey.toP256KAPrivateKey()
        
        // 3. Get the one-time prekey if it was used
        var prekeyKA: P256.KeyAgreement.PrivateKey? = nil
        if let prekeyId = usedPrekeyId, let prekey = try user.getPrekey(keyIdx: prekeyId) {
            prekeyKA = try P256.KeyAgreement.PrivateKey(rawRepresentation: prekey.rawRepresentation)
            print("DEBUG: USING PREKEY")
            // Mark the prekey as used
            user.deletePrekey(keyIdx: prekeyId)
            try await userService.saveUser(user)
        }
        
        // 4. Compute the X3DH shared secret (from receiver's perspective)
        let symmetricKey = try await x3dh.performPassiveX3DH(senderEphemeralKey: senderEphemeralKey, senderIdentityKey: senderIdentityKey, receiverSignedPreKey: signedPrekey, receiverOneTimePreKey: prekeyKA)
        
        // 5. Create a Double Ratchet session with the shared secret
        let session = try createDoubleRatchetSession(
            sharedSecret: symmetricKey,
            localEphemeral: prekeyKA,
            remoteEphemeral: senderEphemeralKey,
            prekeyID: nil
        )
        
        // 6. Serialize the session
        let sessionData = try serializeDoubleRatchetSession(session)
        let jsonStr = String(data: sessionData, encoding: .utf8)!
        print("sessionData from recv: \(jsonStr)")
        
        // 7. Create and save the chat
        let chat = Chat(
            participantUsername: senderUsername,
            ownerUsername: user.username,
            displayName: senderUsername, // Default to username for display
            doubleRatchetSession: sessionData
        )
        
        // 8. Create a welcome message
        let welcomeMessage = Message(
            content: "Chat established securely",
            isFromMe: false,
            status: .delivered
        )
        welcomeMessage.chat = chat
        chat.addMessage(welcomeMessage)
        
        try await chatRepository.saveChat(chat)
        
        return chat
    }
    
    /// Sends a message in a chat
    /// - Parameters:
    ///   - content: The message content
    ///   - chat: The chat to send the message in
    /// - Returns: The created Message object
    func sendMessage(
        content: String, 
        in chat: Chat
    ) async throws -> Message {
        // 1. Deserialize the Double Ratchet session
        let session = try deserializeDoubleRatchetSession(from: chat.doubleRatchetSession)
        
        // 2. Encrypt the message content
        let contentData = Data(content.utf8)
        let encryptedMessage = try session.encrypt(plaintext: contentData)
        
        // 3. Create the message with initial status of sending
        let message = Message(
            content: content,
            isFromMe: true,
            status: .sending
        )
        message.chat = chat
        chat.addMessage(message)
        
        // 4. Re-serialize the updated session state after encryption
        chat.doubleRatchetSession = try serializeDoubleRatchetSession(session)
        
        // Save initial state with "sending" status
        try await chatRepository.saveChat(chat)
        
        // 5. Send the encrypted message to the server
        do {
            // Get username from a user context (this would come from your app's auth context)
            let username = try await getCurrentUsername()
            
            // Send message to server using the MessageGateway
            let response = try await messageGateway.sendMessage(
                encryptedMessage,
                from: username,
                to: chat.participantUsername
            )
            
            // Update message status to "sent" after server confirms receipt
            message.status = .sent
            message.serverId = response.message_id
            message.serverTimestamp = Date(timeIntervalSince1970: TimeInterval(response.timestamp) / 1000)
            
            try await chatRepository.saveChat(chat)
        } catch {
            // If sending fails, mark message as failed
            message.status = .failed
            try await chatRepository.saveChat(chat)
            throw error
        }
        
        return message
    }

    /// Receive and process an incoming message
    /// - Parameters:
    ///   - drMessage: The encrypted DoubleRatchetMessage
    ///   - chat: The chat this message belongs to
    ///   - sender: The sender's username
    /// - Returns: The created Message object if successful
    func receiveMessage(
        _ drMessage: DoubleRatchetMessage,
        in chat: Chat,
        from sender: String
    ) async throws -> Message? {
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
        let message = Message(
            content: content,
            isFromMe: false,
            status: .delivered
        )
        message.chat = chat
        chat.addMessage(message)
        
        do {
            try await chatRepository.saveChat(chat)
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
    
    private func getCurrentUsername() async throws -> String  {
        guard let currentUsername = await userService.selectedUsername else {
            throw ChatManagerError.noCurrentUser
        }
        return currentUsername
    }
}
