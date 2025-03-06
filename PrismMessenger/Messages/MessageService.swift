//
//  MessageService.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation
import CryptoKit
import SwiftData

// MessageError defined in BackendGateway.swift
enum MessageServiceError: Error {
    case messageEncryptionFailed
    case messageDecodingFailed
}

// MARK: - API Request/Response Models

/// API request model for sending a message
struct SendMessageRequest: Encodable {
    var sender_id: String
    var recipient_id: String
    var message: DoubleRatchetMessage
}

/// API response when sending a message
struct SendMessageResponse: Decodable {
    var message_id: UUID
    var timestamp: UInt64
}

/// API model for a message received from the server
struct APIMessage: Decodable {
    var message_id: UUID
    var sender_id: String
    var recipient_id: String
    var message: DoubleRatchetMessage
    var timestamp: UInt64
}

/// API model for marking messages as delivered
struct MarkDeliveredRequest: Encodable {
    var user_id: String
    var message_ids: [UUID]
}

/// Service for sending and receiving messages
class MessageService: ObservableObject {
    private let restClient: RestClient
    private let modelContext: ModelContext
    private let userManager: UserManager
    private let keyService: KeyService
    weak var appContext: AppContext?
    
    init(restClient: RestClient, modelContext: ModelContext, userManager: UserManager, keyService: KeyService) {
        self.restClient = restClient
        self.modelContext = modelContext
        self.userManager = userManager
        self.keyService = keyService
    }
    
    // Circular dependency handling
    
    /// Sends a message to another user
    /// - Parameters:
    ///   - message: The encrypted DoubleRatchetMessage to send
    ///   - sender: The sender's username
    ///   - recipient: The recipient's username
    /// - Returns: The server's response with message ID and timestamp
    func sendMessage(_ message: DoubleRatchetMessage, from sender: String, to recipient: String) async throws -> SendMessageResponse {
        let request = SendMessageRequest(
            sender_id: sender,
            recipient_id: recipient,
            message: message
        )
        
        do {
            let response: SendMessageResponse = try await restClient.post(request, to: "/messages/send")
            return response
        } catch RestClientError.httpError(let statusCode) {
            switch statusCode {
            case 401:
                throw MessageError.unauthorized
            case 500...599:
                throw MessageError.serverError
            default:
                throw MessageError.networkFailure(statusCode)
            }
        }
    }
    
    /// Fetches all available messages for the current user
    /// - Parameter username: The username to fetch messages for
    /// - Returns: Array of received messages
    func fetchMessages(for username: String) async throws -> [APIMessage] {
        print("DEBUG: Fetching messages for \(username)")
        do {
            let messages: [APIMessage] = try await restClient.fetch(from: "/messages/get/\(username)")
            print("DEBUG: Fetched \(messages.count) messages successfully")
            for (i, msg) in messages.enumerated() {
                print("DEBUG: Message [\(i)]: ID=\(msg.message_id), From=\(msg.sender_id), To=\(msg.recipient_id)")
            }
            return messages
        } catch RestClientError.httpError(let statusCode) {
            print("DEBUG: HTTP Error \(statusCode) when fetching messages")
            switch statusCode {
            case 401:
                throw MessageError.unauthorized
            case 404:
                // No messages available is not an error
                print("DEBUG: No messages available (404)")
                return []
            case 500...599:
                throw MessageError.serverError
            default:
                throw MessageError.networkFailure(statusCode)
            }
        } catch {
            print("DEBUG: Unknown error when fetching messages: \(error)")
            throw error
        }
    }
    
    /// Marks messages as delivered on the server
    /// - Parameters:
    ///   - messageIds: Array of message IDs to mark as delivered
    ///   - username: The username marking the messages as delivered
    func markMessagesAsDelivered(messageIds: [UUID], for username: String) async throws {
        let request = MarkDeliveredRequest(
            user_id: username, 
            message_ids: messageIds
        )
        
        do {
            try await restClient.post(request, to: "/messages/mark-delivered")
        } catch RestClientError.httpError(let statusCode) {
            switch statusCode {
            case 401:
                throw MessageError.unauthorized
            case 500...599:
                throw MessageError.serverError
            default:
                throw MessageError.networkFailure(statusCode)
            }
        }
    }
    
    /// Processes received messages, decrypts them, and updates the chat database
    /// - Parameters:
    ///   - messages: Array of messages from the API
    ///   - currentUser: The current user's username
    ///   - chatManager: The ChatManager to handle message storage
    /// - Returns: Array of processed message IDs that were successfully handled
    func processReceivedMessages(
        messages: [APIMessage],
        currentUser: String,
        chatManager: ChatManager
    ) async throws -> [UUID] {
        var processedMessageIds: [UUID] = []
        
        for apiMessage in messages {
            do {
                let drMessage = apiMessage.message
                
                // Get or create the chat for this sender
                var chat: ChatData
                if let existingChat = try await chatManager.getChat(with: apiMessage.sender_id) {
                    chat = existingChat
                } else {
                    // We have an incoming message from an unknown sender - try to establish X3DH
                    do {
                        let keyBundle = try await keyService.getKeyBundle(username: apiMessage.sender_id)
                        
                        let senderEphemeralKey: P256.KeyAgreement.PublicKey
                        if #available(iOS 17.0, *) {
                            // For iOS 17+, use ephemeralKey as Data directly
                            senderEphemeralKey = try P256.KeyAgreement.PublicKey(rawRepresentation: drMessage.header.ephemeralKey)
                        } else {
                            // For older iOS versions, we need to get it from the header
                            senderEphemeralKey = try parseEphemeralKey(from: drMessage)
                        }
                        
                        let senderIdentityKA = try P256.KeyAgreement.PublicKey(
                            compressedRepresentation: keyBundle.identity_key.compressedRepresentation
                        )
                        
                        guard let keyManager = appContext?.keyManager else {
                            continue
                        }
                        
                        // Create the secure chat using X3DH passive mode
                        chat = try await chatManager.createChatFromIncomingMessage(
                            senderUsername: apiMessage.sender_id,
                            senderIdentityKey: senderIdentityKA,
                            senderEphemeralKey: senderEphemeralKey,
                            usedPrekeyId: drMessage.header.oneTimePrekeyID,
                            keyManager: keyManager
                        )
                    } catch {
                        continue
                    }
                }
                
                // Process the decrypted message and save it to the database
                let receivedMessage = try await chatManager.receiveMessage(
                    drMessage,
                    in: chat,
                    from: apiMessage.sender_id
                )
                
                if receivedMessage != nil {
                    processedMessageIds.append(apiMessage.message_id)
                }
            } catch {
                // Continue with other messages if one fails
            }
        }
        
        return processedMessageIds
    }
    
    // Helper methods for parsing message components
    private func parseEphemeralKey(from message: DoubleRatchetMessage) throws -> P256.KeyAgreement.PublicKey {
        // Implementation depends on DoubleRatchetMessage structure
        // This is a fallback method for older iOS versions
        let rawRepresentation = message.header.ephemeralKey
        return try P256.KeyAgreement.PublicKey(rawRepresentation: rawRepresentation)
    }
}
