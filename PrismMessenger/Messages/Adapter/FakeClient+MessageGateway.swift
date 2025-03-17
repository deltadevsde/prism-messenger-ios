//
//  FakeClient+MessageGateway.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation

private struct SendMessageResponse: MessageReceipt {
    let message_id: UUID
    let timestamp = UInt64(Date.now.timeIntervalSince1970 * 1000)
}

private struct MessageResponse: ReceivedMessage {
    let message_id = UUID()
    let sender_id: String
    let recipient_id: String
    let message: DoubleRatchetMessage
    let timestamp = UInt64(Date.now.timeIntervalSince1970 * 1000)
}

private struct StoredMessage {
    let message_id: UUID
    let sender_id: String
    let recipient_id: String
    let message: DoubleRatchetMessage
}

extension FakeClient: MessageGateway {

    func sendMessage(_ message: DoubleRatchetMessage, from sender: String, to recipient: String)
        async throws -> MessageReceipt
    {
        let storedMessage = StoredMessage(
            message_id: UUID(),
            sender_id: sender, recipient_id: recipient, message: message)
        store.addToList(storedMessage)
        return SendMessageResponse(message_id: storedMessage.message_id)
    }

    func fetchMessages(for username: String) async throws -> [ReceivedMessage] {
        store.getList(StoredMessage.self)
            .filter { $0.recipient_id == username }
            .map {
                MessageResponse(
                    sender_id: $0.sender_id,
                    recipient_id: $0.recipient_id,
                    message: $0.message)
            }
    }

    func markMessagesAsDelivered(messageIds: [UUID], for username: String) async throws {
        // do nothing
    }
}
