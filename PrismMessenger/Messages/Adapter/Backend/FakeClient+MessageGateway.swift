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

private struct MessageResponse: ReceivedMessage, Identifiable {
    var id: UUID { messageId }

    let messageId = UUID()
    let senderId: UUID
    let recipientId: UUID
    let message: DoubleRatchetMessage
    let timestamp = UInt64(Date.now.timeIntervalSince1970 * 1000)
}

private struct MessageHandler: Identifiable {
    var id: UUID { recipientId }

    var recipientId: UUID
    var onMessageReceived: ((any ReceivedMessage) async throws -> Void)
}

extension FakeClient: MessageSenderGateway, MessageReceiverGateway {

    private var messageStore: InMemoryStore<MessageResponse> {
        storeProvider.provideTypedStore()
    }

    private var messageHandlerStore: InMemoryStore<MessageHandler> {
        storeProvider.provideTypedStore()
    }

    @MainActor
    func sendMessage(_ message: DoubleRatchetMessage, to recipientId: UUID)
        async throws -> MessageReceipt
    {
        let storedMessage = MessageResponse(
            senderId: currentAccountId!,
            recipientId: recipientId,
            message: message
        )
        messageStore.save(storedMessage)

        // Simulate backend sending message to recipient
        if let handler = messageHandlerStore.get(byId: recipientId) {
            try await handler.onMessageReceived(storedMessage)
        }

        return SendMessageResponse(messageId: storedMessage.messageId)
    }

    func markMessagesAsDelivered(messageIds: [UUID]) async throws {
        messageStore.remove {
            messageIds.contains($0.messageId)
        }
    }

    func handleIncomingMessages(_ handler: @escaping (any ReceivedMessage) async throws -> Void) {
        Task {
            print("FakeClient: Setting up message handler for \(await currentAccountId!)")
            messageHandlerStore.save(
                MessageHandler(recipientId: await currentAccountId!, onMessageReceived: handler)
            )
        }
    }
}
