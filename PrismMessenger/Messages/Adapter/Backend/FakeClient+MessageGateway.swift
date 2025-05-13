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
    let senderId: UUID
    let recipientId: UUID
    let message: DoubleRatchetMessage
    let timestamp = UInt64(Date.now.timeIntervalSince1970 * 1000)
}

extension FakeClient: MessageGateway {

    func sendMessage(_ message: DoubleRatchetMessage, to recipientId: UUID)
        async throws -> MessageReceipt
    {
        guard let currentUser = try await userService.getCurrentUser() else {
            throw FakeClientError.authenticationRequired
        }

        let storedMessage = MessageResponse(
            senderId: currentUser.id,
            recipientId: recipientId,
            message: message)
        store.addToList(storedMessage)
        return SendMessageResponse(messageId: storedMessage.messageId)
    }

    func fetchMessages() async throws -> [ReceivedMessage] {
        let currentUser = try await userService.getCurrentUser()

        return store.getList(MessageResponse.self)
            .filter { $0.recipientId == currentUser?.id }
    }

    func markMessagesAsDelivered(messageIds: [UUID]) async throws {
        store.removeFromList(MessageResponse.self) {
            messageIds.contains($0.messageId)
        }
    }
}
