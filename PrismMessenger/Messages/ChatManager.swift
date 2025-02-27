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
    func createChat(
        username: String,
        sharedSecret: SymmetricKey,
        ephemeralPublicKey: P256.KeyAgreement.PublicKey,
        usedPrekeyId: UInt64?
    ) throws -> ChatData {
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
    
    /// Retrieves a chat with a specific participant, if it exists
    /// - Parameter username: The participant's username
    /// - Returns: The ChatData object if found, nil otherwise
    func getChat(with username: String) throws -> ChatData? {
        let descriptor = FetchDescriptor<ChatData>(
            predicate: #Predicate { $0.participantUsername == username }
        )
        let chats = try modelContext.fetch(descriptor)
        return chats.first
    }
    
    /// Gets a list of all chats, sorted by last message timestamp
    /// - Returns: Array of all chats
    func getAllChats() throws -> [ChatData] {
        let descriptor = FetchDescriptor<ChatData>(
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
    /// - Returns: The created MessageData object
    func sendMessage(content: String, in chat: ChatData) throws -> MessageData {
        // 1. Deserialize the Double Ratchet session
        let session = try deserializeDoubleRatchetSession(from: chat.doubleRatchetSession)
        
        // 2. Encrypt the message content
        let contentData = Data(content.utf8)
        let encrypted = try session.encrypt(plaintext: contentData)
        
        // TODO: Send the encrypted message to the server
        // let success = await sendToServer(encrypted, recipient: chat.participantUsername)
        
        // 3. Re-serialize the updated session state
        chat.doubleRatchetSession = try serializeDoubleRatchetSession(session)
        
        // 4. Create and save the message
        let message = MessageData(
            content: content,
            isFromMe: true,
            status: .sent
        )
        message.chat = chat
        chat.addMessage(message)
        
        try modelContext.save()
        
        return message
    }
}