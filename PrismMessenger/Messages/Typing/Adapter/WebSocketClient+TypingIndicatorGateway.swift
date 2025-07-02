//
//  WebSocketClient+TypingGateway.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation

private struct TypingWebSocketMessage: WebSocketMessage {
    var type = "typing"
    let accountId: UUID
    let isTyping: Bool
}

private struct TypingStatus: Codable {
    let accountId: UUID
    let isTyping: Bool
}

extension WebSocketClient: TypingGateway {

    func sendTypingStatus(for accountId: UUID, isTyping: Bool) async throws {
        let typingMessage = TypingWebSocketMessage(accountId: accountId, isTyping: isTyping)
        try await sendMessage(typingMessage)
    }

    func handleTypingChanges(_ handler: @escaping (UUID, Bool) async throws -> Void) {
        setMessageHandler(for: "typing") { (message: TypingWebSocketMessage) in
            try await handler(message.accountId, message.isTyping)
        }
    }
}
