//
//  WebSocketClient+PresenceGateway.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation

private struct PresenceWebSocketMessage: WebSocketMessage {
    var type = "presence"
    let accountId: UUID
    let status: PresenceStatus
}

extension WebSocketClient: PresenceRtcGateway {

    func handlePresenceChanges(_ handler: @escaping (UUID, PresenceStatus) async throws -> Void) {
        setMessageHandler(for: "presence") { (message: PresenceWebSocketMessage) in
            try await handler(message.accountId, message.status)
        }
    }

    func sendPresenceStatus(for accountId: UUID, status: PresenceStatus) async throws {
        let presenceMessage = PresenceWebSocketMessage(accountId: accountId, status: status)
        try await sendMessage(presenceMessage)
    }
}
