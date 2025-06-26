//
//  RestClient+MessageGateway.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation

private let log = Log.messages

/// API request model for sending a message
private struct SendMessageRequest: Encodable {
    let recipientId: UUID
    let message: DoubleRatchetMessage
}

/// API response when sending a message
private struct SendMessageResponse: Decodable, MessageReceipt {
    let messageId: UUID
    let timestamp: UInt64
}

/// API model for a message received from the server
private struct MessageResponse: Decodable, ReceivedMessage {
    let messageId: UUID
    let senderId: UUID
    let recipientId: UUID
    let message: DoubleRatchetMessage
    let timestamp: UInt64
}

/// API model for marking messages as delivered
private struct MarkDeliveredRequest: Encodable {
    let messageIds: [UUID]
}

extension RestClient: MessageSenderGateway {

    func sendMessage(_ message: DoubleRatchetMessage, to recipientId: UUID)
        async throws -> MessageReceipt
    {
        let request = SendMessageRequest(
            recipientId: recipientId,
            message: message
        )

        do {
            guard
                let response: SendMessageResponse = try await post(
                    request,
                    to: "/messages/send",
                    accessLevel: .authenticated
                )
            else {
                throw MessageGatewayError.invalidResponse
            }
            return response
        } catch RestClientError.httpError(let statusCode) {
            throw MessageGatewayError.requestFailed(statusCode)
        }
    }

    func markMessagesAsDelivered(messageIds: [UUID]) async throws {
        let request = MarkDeliveredRequest(
            messageIds: messageIds
        )

        do {
            try await post(request, to: "/messages/mark-delivered", accessLevel: .authenticated)
        } catch RestClientError.httpError(let statusCode) {
            throw MessageGatewayError.requestFailed(statusCode)
        }
    }

}
