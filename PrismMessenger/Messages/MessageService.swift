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
    var ephemeral_key: P256.KeyAgreement.PublicKey
    var message_number: UInt64
    var previous_message_number: UInt64
    var one_time_prekey_id: UInt64?
    
    // Convert from our local model to API model
    init(from header: DoubleRatchetHeader) throws {
        self.ephemeral_key = header.ephemeralKey
        self.message_number = header.messageNumber
        self.previous_message_number = header.previousMessageNumber
        self.one_time_prekey_id = header.oneTimePrekeyID
    }
    
    // Convert from API model to our local model
    func toDoubleRatchetHeader() -> DoubleRatchetHeader {
        return DoubleRatchetHeader(
            ephemeralKey: ephemeral_key,
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
        print("DEBUG: Inside toDoubleRatchetMessage")
        
        do {
            // Log the ephemeral key details
            print("DEBUG: ephemeral_key: \(self.header.ephemeral_key)")
            print("DEBUG: ephemeral_key size: \(self.header.ephemeral_key.compressedRepresentation.count) bytes")
            
            // Convert the header
            let localHeader = self.header.toDoubleRatchetHeader()
            print("DEBUG: Converted to local header")
            
            // To match the sending side, use a zero nonce
            // In a real app, the nonce would be transmitted with the message
            let nonceData = Data(repeating: 0, count: 12)
            print("DEBUG: Using zero nonce for consistency with sender")
            let nonce = try AES.GCM.Nonce(data: nonceData)
            print("DEBUG: Created nonce")
            
            // Create and return the local message
            return DoubleRatchetMessage(
                header: localHeader,
                ciphertext: Data(ciphertext),
                nonce: nonce
            )
        } catch {
            print("DEBUG: Error in toDoubleRatchetMessage: \(error)")
            throw error
        }
    }
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
                print("DEBUG: Converting message to local format")
                print("DEBUG: Ephemeral key type: \(type(of: apiMessage.message.header.ephemeral_key))")
                print("DEBUG: Ephemeral key data: \(apiMessage.message.header.ephemeral_key.compressedRepresentation.count) bytes")
                
                // Convert API message to our local message format
                var drMessage: DoubleRatchetMessage
                do {
                    drMessage = try apiMessage.message.toDoubleRatchetMessage()
                    print("DEBUG: Successfully converted message to local format")
                } catch {
                    print("DEBUG: Failed to convert message: \(error)")
                    processedMessageIds.append(apiMessage.message_id)
                    continue
                }
                
                // Get or create the chat for this sender
                var chat: ChatData
                if let existingChat = try await chatManager.getChat(with: apiMessage.sender_id) {
                    chat = existingChat
                } else {
                    // We have an incoming message from an unknown sender - try to establish X3DH
                    print("Received message from unknown sender, establishing secure channel with X3DH")
                    
                    do {
                        // 1. Get the sender's key bundle to obtain their identity key
                        guard let keyBundle = try await appContext?.keyService.getKeyBundle(username: apiMessage.sender_id) else {
                            print("Failed to get key bundle for \(apiMessage.sender_id)")
                            // TODO: Throw error?
                            continue
                        }
                        
                        print("DEBUG: Got key bundle for \(apiMessage.sender_id)")
                        print("DEBUG: Identity key representation size: \(keyBundle.identity_key.rawRepresentation.count)")
                        print("DEBUG: Identity key compressed size: \(keyBundle.identity_key.compressedRepresentation.count)")
                        print("DEBUG: Message header dump: \(drMessage.header)")
                        
                        // 3. First, create a P256.Signing.PublicKey from the ephemeral key, then convert to KeyAgreement
                        print("DEBUG: Converting ephemeral key from message")
                        
                        // First try to create a Signing.PublicKey, then convert
                        var senderEphemeralKey = drMessage.header.ephemeralKey
                        
                        // 4. Convert identity key using the same method as in X3DH.swift
                        print("DEBUG: Converting identity key")
                        let senderIdentityKA = try P256.KeyAgreement.PublicKey(
                            compressedRepresentation: keyBundle.identity_key.compressedRepresentation
                        )
                        
                        // 4. Get key manager for secure operations
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
                            usedPrekeyId: drMessage.header.oneTimePrekeyID,
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
