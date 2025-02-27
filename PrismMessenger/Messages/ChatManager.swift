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
        // 1. Deserialize the Double Ratchet session
        let session = try deserializeDoubleRatchetSession(from: chat.doubleRatchetSession)
        
        // 2. Decrypt the message content
        let decryptedData = try session.decrypt(
            ciphertext: drMessage.ciphertext,
            header: drMessage.header,
            nonce: drMessage.nonce
        )
        
        // 3. Convert decrypted data to a string
        guard let content = String(data: decryptedData, encoding: .utf8) else {
            throw MessageError.messageDecodingFailed
        }
        
        // 4. Re-serialize the updated session state after decryption
        chat.doubleRatchetSession = try serializeDoubleRatchetSession(session)
        
        // 5. Create and save the message
        let message = MessageData(
            content: content,
            isFromMe: false,
            status: .delivered
        )
        message.chat = chat
        chat.addMessage(message)
        
        try modelContext.save()
        
        return message
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