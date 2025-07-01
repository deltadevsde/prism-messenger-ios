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
    private let messageSenderGateway: MessageSenderGateway
    private let messageReceiverGateway: MessageReceiverGateway
    private let keyGateway: KeyGateway
    private let userService: UserService
    private let chatService: ChatService
    private let messageNotificationService: MessageNotificationService

    init(
        messageSenderGateway: MessageSenderGateway,
        messageReceiverGateway: MessageReceiverGateway,
        keyGateway: KeyGateway,
        userService: UserService,
        chatService: ChatService,
        messageNotificationService: MessageNotificationService
    ) {
        self.messageSenderGateway = messageSenderGateway
        self.messageReceiverGateway = messageReceiverGateway
        self.keyGateway = keyGateway
        self.userService = userService
        self.chatService = chatService
        self.messageNotificationService = messageNotificationService
    }

    /// Set up real-time message handling via WebSocket
    func setupMessageHandling() {
        messageReceiverGateway.handleIncomingMessages { [weak self] receivedMessage in
            Task {
                await self?.handleIncomingMessage(receivedMessage)
            }
        }
    }

    /// Handle a single incoming message received via WebSocket
    /// - Parameter receivedMessage: The message received in real-time
    private func handleIncomingMessage(_ receivedMessage: ReceivedMessage) async {
        log.debug(
            "Received real-time message ID: \(receivedMessage.messageId) from \(receivedMessage.senderId)"
        )

        do {
            // Process the single received message
            let processedMessages = try await processReceivedMessages(
                receivedMessages: [receivedMessage]
            )

            // Mark the message as delivered if it was processed successfully
            if let processedMessage = processedMessages.first,
               let serverId = processedMessage.serverId
            {
                log.debug("Marking real-time message as delivered: \(serverId)")
                try await messageSenderGateway.markMessagesAsDelivered(messageIds: [serverId])
            }
        } catch {
            log.error("Failed to process real-time message \(receivedMessage.messageId): \(error)")
        }
    }

    /// Processes received messages, decrypts them, and updates the chat database
    /// - Parameters:
    ///   - messages: Array of received messages from the API
    /// - Returns: Array of processed messages that were successfully handled
    func processReceivedMessages(
        receivedMessages: [ReceivedMessage],
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
