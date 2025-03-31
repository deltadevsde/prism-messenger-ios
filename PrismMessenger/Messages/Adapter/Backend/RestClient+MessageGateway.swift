import Foundation

private let log = Log.messages

/// API request model for sending a message
private struct SendMessageRequest: Encodable {
    let recipientUsername: String
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
    let senderUsername: String
    let recipientUsername: String
    let message: DoubleRatchetMessage
    let timestamp: UInt64
}

/// API model for marking messages as delivered
private struct MarkDeliveredRequest: Encodable {
    let messageIds: [UUID]
}

extension RestClient: MessageGateway {

    func sendMessage(_ message: DoubleRatchetMessage, to recipientUsername: String)
        async throws -> MessageReceipt
    {
        let request = SendMessageRequest(
            recipientUsername: recipientUsername,
            message: message
        )

        do {
            let response: SendMessageResponse = try await post(
                request,
                to: "/messages/send",
                accessLevel: .authenticated
            )
            return response
        } catch RestClientError.httpError(let statusCode) {
            throw MessageGatewayError.requestFailed(statusCode)
        }
    }

    func fetchMessages() async throws -> [ReceivedMessage] {
        log.debug("Fetching messages")
        do {
            let messages: [MessageResponse] = try await fetch(
                from: "/messages/get", accessLevel: .authenticated)
            log.debug("Fetched \(messages.count) messages successfully")
            return messages
        } catch RestClientError.httpError(let statusCode) {
            log.debug("HTTP Error \(statusCode) when fetching messages")
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
