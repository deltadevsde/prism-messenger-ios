//
//  FakeClient+MessageGateway.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation

private struct SendMessageResponse: MessageReceipt {
    let messageId: UUID
    let timestamp = UInt64(Date.now.timeIntervalSince1970 * 1000)
}

private struct MessageResponse: ReceivedMessage {
    let messageId = UUID()
    let senderUsername: String
    let recipientUsername: String
    let message: DoubleRatchetMessage
    let timestamp = UInt64(Date.now.timeIntervalSince1970 * 1000)
}

extension FakeClient: MessageGateway {

    func sendMessage(_ message: DoubleRatchetMessage, to recipientUsername: String)
        async throws -> MessageReceipt
    {
        let senderUsername = await userService.selectedUsername!
        let storedMessage = MessageResponse(
            senderUsername: senderUsername,
            recipientUsername: recipientUsername,
            message: message)
        store.addToList(storedMessage)
        return SendMessageResponse(messageId: storedMessage.messageId)
    }

    func fetchMessages() async throws -> [ReceivedMessage] {
        let currentUser = try await userService.getCurrentUser()

        return store.getList(MessageResponse.self)
            .filter { $0.recipientUsername == currentUser?.username }
    }

    func markMessagesAsDelivered(messageIds: [UUID]) async throws {
        store.removeFromList(MessageResponse.self) {
            messageIds.contains($0.messageId)
        }
    }
}
