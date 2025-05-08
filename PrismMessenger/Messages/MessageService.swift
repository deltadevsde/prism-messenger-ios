//
//  MessageService.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import CryptoKit
import Foundation
import SwiftData

private let log = Log.messages

enum MessageError: Error {
    case assigningChatFailed
}

/// Concrete implementation of the MessageServiceProtocol
@MainActor
class MessageService: ObservableObject {
    private let messageGateway: MessageGateway
    private let keyGateway: KeyGateway
    private let userService: UserService
    private let chatService: ChatService
    private let messageNotificationService: MessageNotificationService

    init(
        messageGateway: MessageGateway,
        keyGateway: KeyGateway,
        userService: UserService,
        chatService: ChatService,
        messageNotificationService: MessageNotificationService
    ) {
        self.messageGateway = messageGateway
        self.keyGateway = keyGateway
        self.userService = userService
        self.chatService = chatService
        self.messageNotificationService = messageNotificationService
    }

    /// Fetches new messages from the server and processes them
    /// - Returns: The number of new messages processed
    @discardableResult
    func fetchAndProcessMessages() async throws -> Int {
        guard let currentUser = try await userService.getCurrentUser() else {
            return 0
        }

        do {
            let messages = try await messageGateway.fetchMessages()

            log.debug("Processing \(messages.count) fetched messages ...")
            if messages.isEmpty {
                return 0
            }
            let processedMessages = try await processReceivedMessages(
                receivedMessages: messages,
                currentUser: currentUser.username
            )

            let processedIds = processedMessages.compactMap { $0.serverId }
            if !processedIds.isEmpty {
                log.debug("Marking \(processedIds.count) messages as delivered on the server ...")
                try await messageGateway.markMessagesAsDelivered(
                    messageIds: processedIds
                )
            }

            return processedMessages.count
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
        receivedMessages: [ReceivedMessage],
        currentUser: String
    ) async throws -> [Message] {
        var processedMessages: [Message] = []

        for receivedMessage in receivedMessages {
            log.debug(
                "Processing message ID: \(receivedMessage.messageId) from \(receivedMessage.senderId)"
            )

            do {
                // Get or create the chat for this sender
                let chat = try await fetchOrCreateChat(for: receivedMessage)
                log.info(
                    "Successfully established secure channel with \(receivedMessage.senderId)"
                )

                // Process the decrypted message and save it to the database
                guard
                    let message = try await chatService.receiveMessage(
                        receivedMessage,
                        in: chat,
                    )
                else {
                    continue
                }

                await messageNotificationService.potentiallySendNotification(for: message)

                processedMessages.append(message)
            } catch {
                log.error("Failed to process message \(receivedMessage.messageId): \(error)")
            }
        }

        return processedMessages
    }

    private func fetchOrCreateChat(for message: ReceivedMessage) async throws -> Chat {
        do {
            if let existingChat = try await chatService.getChat(with: message.senderId) {
                return existingChat
            }
        } catch {
            throw MessageError.assigningChatFailed
        }

        // We have an incoming message from an unknown sender - try to establish X3DH
        log.debug("Received message from unknown sender, establishing secure channel with X3DH")

        let drMessage = message.message

        do {
            guard let keyBundle = try await keyGateway.fetchKeyBundle(for: message.senderId)
            else {
                throw MessageError.assigningChatFailed
            }

            log.debug("Got key bundle for \(message.senderId)")
            log.debug(
                "Identity key representation size: \(keyBundle.identityKey.rawRepresentation.count)"
            )
            log.debug(
                "Identity key compressed size: \(keyBundle.identityKey.compressedRepresentation.count)"
            )
            log.debug("Message header dump: \(String(describing: drMessage.header))")

            let senderEphemeralKey = drMessage.header.ephemeralKey

            // 5. Create the secure chat using X3DH passive mode
            return try await chatService.createChatFromIncomingMessage(
                senderId: message.senderId,
                senderIdentityKey: keyBundle.identityKey.forKA(),
                senderEphemeralKey: senderEphemeralKey,
                usedPrekeyId: drMessage.header.oneTimePrekeyId
            )
        } catch {
            log.error("Failed to establish secure channel: \(error)")
            throw MessageError.assigningChatFailed
        }
    }
}
