//
//  MessageService.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation
import CryptoKit
import SwiftData

private let log = Log.messages

enum MessageError: Error {
    case networkFailure(Int)
    case messageEncryptionFailed
    case messageDecodingFailed
    case unauthorized
    case serverError
}

/// Concrete implementation of the MessageServiceProtocol
class MessageService: ObservableObject {
    private let messageGateway: MessageGateway
    private let keyGateway: KeyGateway
    private let userService: UserService
    private let chatService: ChatService
    
    init(messageGateway: MessageGateway, keyGateway: KeyGateway, userService: UserService, chatService: ChatService) {
        self.messageGateway = messageGateway
        self.keyGateway = keyGateway
        self.userService = userService
        self.chatService = chatService
    }
    
    /// Fetches new messages from the server and processes them
    /// - Returns: The number of new messages processed
    @MainActor
    func fetchAndProcessMessages() async throws -> Int {
        guard let currentUser = try await userService.getCurrentUser() else {
            return 0
        }
        
        return try await processMessagesForUser(currentUser.username)
    }
    
    /// Helper method to process messages for a specific username
    @MainActor
    private func processMessagesForUser(_ username: String) async throws -> Int {
        
        do {
            // 1. Fetch new messages from the server
            let messages = try await messageGateway.fetchMessages(for: username)
            
            if messages.isEmpty {
                return 0
            }
            
            // 2. Process the messages and get the IDs of processed messages
            let processedIds = try await processReceivedMessages(
                messages: messages,
                currentUser: username
            )
            
            if !processedIds.isEmpty {
                // 3. Mark the processed messages as delivered on the server
                try await messageGateway.markMessagesAsDelivered(
                    messageIds: processedIds,
                    for: username
                )
            }
            
            return processedIds.count
        } catch {
            log.warning("Error processing messages: \(error)")
            return 0
        }
    }
    
    /// Processes received messages, decrypts them, and updates the chat database
    /// - Parameters:
    ///   - messages: Array of messages from the API
    ///   - currentUser: The current user's username
    ///   - chatService: The ChatService to handle message storage
    /// - Returns: Array of processed message IDs that were successfully handled
    func processReceivedMessages(
        messages: [ReceivedMessage],
        currentUser: String
    ) async throws -> [UUID] {
        var processedMessageIds: [UUID] = []

        print("DEBUG: Processing \(messages.count) messages for user \(currentUser)")

        for apiMessage in messages {
            print("DEBUG: Processing message ID: \(apiMessage.messageId) from \(apiMessage.senderId)")
            
            do {
                
                let drMessage = apiMessage.message
                
                // Get or create the chat for this sender
                var chat: Chat
                if let existingChat = try await chatService.getChat(with: apiMessage.senderId) {
                    chat = existingChat
                } else {
                    // We have an incoming message from an unknown sender - try to establish X3DH
                    print("Received message from unknown sender, establishing secure channel with X3DH")
                    
                    do {
                        guard let keyBundle = try await keyGateway.fetchKeyBundle(for: apiMessage.senderId) else {
                            print("Failed to get key bundle for \(apiMessage.senderId)")
                            // TODO: Throw error?
                            continue
                        }
                        
                        print("DEBUG: Got key bundle for \(apiMessage.senderId)")
                        print("DEBUG: Identity key representation size: \(keyBundle.identityKey.rawRepresentation.count)")
                        print("DEBUG: Identity key compressed size: \(keyBundle.identityKey.compressedRepresentation.count)")
                        print("DEBUG: Message header dump: \(drMessage.header)")
                        
                        let senderEphemeralKey = drMessage.header.ephemeralKey
                        
                        print("DEBUG: Converting identity key")
                        let senderIdentityKA = try P256.KeyAgreement.PublicKey(
                            compressedRepresentation: keyBundle.identityKey.compressedRepresentation
                        )
                        
                        // 5. Create the secure chat using X3DH passive mode
                        chat = try await chatService.createChatFromIncomingMessage(
                            senderUsername: apiMessage.senderId,
                            senderIdentityKey: senderIdentityKA,
                            senderEphemeralKey: senderEphemeralKey,
                            usedPrekeyId: drMessage.header.oneTimePrekeyId
                        )
                        
                        print("Successfully established secure channel with \(apiMessage.senderId)")
                    } catch {
                        print("Failed to establish secure channel: \(error)")
                        // TODO: throw
                        continue
                    }
                }
                
                // Process the decrypted message and save it to the database
                let receivedMessage = try await chatService.receiveMessage(
                    drMessage,
                    in: chat,
                    from: apiMessage.senderId
                )
                
                if receivedMessage != nil {
                    processedMessageIds.append(apiMessage.messageId)
                }
            } catch {
                log.error("Failed to process message \(message.messageId): \(error)")
            }
        }
        
        return processedMessageIds
    }
}

