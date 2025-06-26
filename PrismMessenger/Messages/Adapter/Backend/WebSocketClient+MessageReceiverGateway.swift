//
//  WebSocketClient+MessageGateway.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation

private let log = Log.messages

/// WebSocket message for receiving messages
private struct ReceivedMessageWebSocketMessage: WebSocketMessage, ReceivedMessage {
    var type = "message"
    let messageId: UUID
    let senderId: UUID
    let recipientId: UUID
    let message: DoubleRatchetMessage
    let timestamp: UInt64
}

extension WebSocketClient: MessageReceiverGateway {

    func handleIncomingMessages(_ handler: @escaping (ReceivedMessage) async throws -> Void) {
        setMessageHandler(for: "message") { (message: ReceivedMessageWebSocketMessage) in
            try await handler(message)
        }
    }
}
