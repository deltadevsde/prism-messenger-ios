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
    var message: APIDoubleRatchetMessage
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
    var message: APIDoubleRatchetMessage
    var timestamp: UInt64
}

/// API model for marking messages as delivered
struct MarkDeliveredRequest: Encodable {
    var user_id: String
    var message_ids: [UUID]
}

/// API model for header structure used in API requests/responses
struct APIDoubleRatchetHeader: Codable {
    var ephemeral_key: P256.Signing.PublicKey
    var message_number: UInt64
    var previous_message_number: UInt64
    var one_time_prekey_id: UInt64?
    
    // Convert from our local model to API model
    init(from header: DoubleRatchetHeader) throws {
        self.ephemeral_key = try P256.Signing.PublicKey(compressedRepresentation: header.ephemeralKey)
        self.message_number = header.messageNumber
        self.previous_message_number = header.previousMessageNumber
        self.one_time_prekey_id = header.oneTimePrekeyID
    }
    
    // Convert from API model to our local model
    func toDoubleRatchetHeader() -> DoubleRatchetHeader {
        return DoubleRatchetHeader(
            ephemeralKey: ephemeral_key.compressedRepresentation,
            messageNumber: message_number,
            previousMessageNumber: previous_message_number,
            oneTimePrekeyID: one_time_prekey_id
        )
    }
}

/// API model for double ratchet message used in API requests/responses
struct APIDoubleRatchetMessage: Codable {
    var header: APIDoubleRatchetHeader
    var ciphertext: [UInt8]
    
    // Convert from our local model to API model
    init(from message: DoubleRatchetMessage) throws {
        self.header = try APIDoubleRatchetHeader(from: message.header)
        self.ciphertext = [UInt8](message.ciphertext)
    }
    
    // Try to convert from API model to our local model
    func toDoubleRatchetMessage() throws -> DoubleRatchetMessage {
        // Create a nonce from the header data
        // Note: In a real implementation, the nonce should be part of the API message
        // This is a simplification for demo purposes
        let nonceData = Data(repeating: 0, count: 12) // Create a 12-byte zero nonce
        guard let nonce = try? AES.GCM.Nonce(data: nonceData) else {
            throw MessageError.messageDecodingFailed
        }
        
        return DoubleRatchetMessage(
            header: header.toDoubleRatchetHeader(),
            ciphertext: Data(ciphertext),
            nonce: nonce
        )
    }
}

/// Service for sending and receiving messages
class MessageService: ObservableObject {
    private let restClient: RestClient
    private let modelContext: ModelContext
    weak var appLaunch: AppLaunch?
    
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
            message: try APIDoubleRatchetMessage(from: message)
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
        do {
            let messages: [APIMessage] = try await restClient.fetch(from: "/messages/get/\(username)")
            return messages
        } catch RestClientError.httpError(let statusCode) {
            switch statusCode {
            case 401:
                throw MessageError.unauthorized
            case 404:
                // No messages available is not an error
                return []
            case 500...599:
                throw MessageError.serverError
            default:
                throw MessageError.networkFailure(statusCode)
            }
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
            // Skip outgoing messages that somehow came back to us
            if apiMessage.sender_id == currentUser {
                processedMessageIds.append(apiMessage.message_id)
                continue
            }
            
            do {
                // Convert API message to our local message format
                let drMessage = try apiMessage.message.toDoubleRatchetMessage()
                
                // Get or create the chat for this sender
                var chat: ChatData
                if let existingChat = try await chatManager.getChat(with: apiMessage.sender_id) {
                    chat = existingChat
                } else {
                    // TODO: Properly handle new chats that are started by the other person
                    // This is a simplified version - in a real app, we would need to handle X3DH
                    print("Warning: Received message from unknown sender, creating new chat")
                    continue
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
                // We still mark the message as processed to avoid processing it again
                processedMessageIds.append(apiMessage.message_id)
            }
        }
        
        return processedMessageIds
    }
}
