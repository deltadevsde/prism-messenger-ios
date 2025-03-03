//
//  MessageService.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation
import CryptoKit
import SwiftData

enum MessageError: Error {
    case networkFailure(Int)
    case messageEncryptionFailed
    case messageDecodingFailed
    case unauthorized
    case serverError
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
    weak var appLaunch: AppLaunch?
    weak var appContext: AppContext?
    
    init(restClient: RestClient, modelContext: ModelContext) {
        self.restClient = restClient
        self.modelContext = modelContext
    }
    
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
    
    /// Gets the current username from appLaunch or database
    /// - Returns: The current username
    @MainActor
    func getCurrentUsername() throws -> String {
        // First try appLaunch
        if let username = appLaunch?.selectedUsername, !username.isEmpty {
            return username
        }
        
        // Then try the database directly
        let descriptor = FetchDescriptor<UserData>()
        let users = try modelContext.fetch(descriptor)
        if let firstUser = users.first {
            return firstUser.username
        }
        throw MessageError.unauthorized
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
        
        print("DEBUG: Processing \(messages.count) messages for user \(currentUser)")
        
        for apiMessage in messages {
            print("DEBUG: Processing message ID: \(apiMessage.message_id) from \(apiMessage.sender_id)")
            
            do {
                
                let drMessage = apiMessage.message
                
                // Get or create the chat for this sender
                var chat: ChatData
                if let existingChat = try await chatManager.getChat(with: apiMessage.sender_id) {
                    chat = existingChat
                } else {
                    // We have an incoming message from an unknown sender - try to establish X3DH
                    print("Received message from unknown sender, establishing secure channel with X3DH")
                    
                    do {
                        guard let keyBundle = try await appContext?.keyService.getKeyBundle(username: apiMessage.sender_id) else {
                            print("Failed to get key bundle for \(apiMessage.sender_id)")
                            // TODO: Throw error?
                            continue
                        }
                        
                        print("DEBUG: Got key bundle for \(apiMessage.sender_id)")
                        print("DEBUG: Identity key representation size: \(keyBundle.identity_key.rawRepresentation.count)")
                        print("DEBUG: Identity key compressed size: \(keyBundle.identity_key.compressedRepresentation.count)")
                        print("DEBUG: Message header dump: \(drMessage.header)")
                        
                        var senderEphemeralKey = drMessage.header.ephemeral_key
                        
                        print("DEBUG: Converting identity key")
                        let senderIdentityKA = try P256.KeyAgreement.PublicKey(
                            compressedRepresentation: keyBundle.identity_key.compressedRepresentation
                        )
                        
                        guard let keyManager = appContext?.keyManager else {
                            print("KeyManager not available")
                            // TODO: Throw error
                            continue
                        }
                        
                        // 5. Create the secure chat using X3DH passive mode
                        chat = try await chatManager.createChatFromIncomingMessage(
                            senderUsername: apiMessage.sender_id,
                            senderIdentityKey: senderIdentityKA,
                            senderEphemeralKey: senderEphemeralKey,
                            usedPrekeyId: drMessage.header.one_time_prekey_id,
                            keyManager: keyManager
                        )
                        
                        print("Successfully established secure channel with \(apiMessage.sender_id)")
                    } catch {
                        print("Failed to establish secure channel: \(error)")
                        // TODO: throw
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
                print("Failed to process message: \(error)")
            }
        }
        
        return processedMessageIds
    }
}
