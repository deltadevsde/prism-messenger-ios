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
    let senderId: String
    let recipientId: String
    let message: DoubleRatchetMessage
    let timestamp = UInt64(Date.now.timeIntervalSince1970 * 1000)
}

extension FakeClient: MessageGateway {

    func sendMessage(_ message: DoubleRatchetMessage, from sender: String, to recipient: String)
        async throws -> MessageReceipt
    {
        let storedMessage = MessageResponse(
            senderId: sender,
            recipientId: recipient,
            message: message)
        store.addToList(storedMessage)
        return SendMessageResponse(messageId: storedMessage.messageId)
    }

    func fetchMessages(for username: String) async throws -> [ReceivedMessage] {
        return store.getList(MessageResponse.self)
            .filter { $0.recipientId == username }
    }

    func markMessagesAsDelivered(messageIds: [UUID], for username: String) async throws {
        store.removeFromList(MessageResponse.self) {
            messageIds.contains($0.messageId)
        }
    }
}
