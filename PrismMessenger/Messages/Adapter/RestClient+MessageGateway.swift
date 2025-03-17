import Foundation

/// API request model for sending a message
private struct SendMessageRequest: Encodable {
    let sender_id: String
    let recipient_id: String
    let message: DoubleRatchetMessage
}

/// API response when sending a message
private struct SendMessageResponse: Decodable, MessageReceipt {
    let message_id: UUID
    let timestamp: UInt64
}

/// API model for a message received from the server
private struct MessageResponse: Decodable, ReceivedMessage {
    let message_id: UUID
    let sender_id: String
    let recipient_id: String
    let message: DoubleRatchetMessage
    let timestamp: UInt64
}

/// API model for marking messages as delivered
private struct MarkDeliveredRequest: Encodable {
    let user_id: String
    let message_ids: [UUID]
}

extension RestClient: MessageGateway {
    func sendMessage(_ message: DoubleRatchetMessage, from sender: String, to recipient: String)
        async throws -> MessageReceipt
    {
        let request = SendMessageRequest(
            sender_id: sender,
            recipient_id: recipient,
            message: message
        )

        do {
            let response: SendMessageResponse = try await post(request, to: "/messages/send")
            return response
        } catch RestClientError.httpError(let statusCode) {
            throw MessageGatewayError.requestFailed(statusCode)
        }
    }

    func fetchMessages(for username: String) async throws -> [ReceivedMessage] {
        print("DEBUG: Fetching messages for \(username)")
        do {
            let messages: [MessageResponse] = try await fetch(from: "/messages/get/\(username)")
            print("DEBUG: Fetched \(messages.count) messages successfully")
            return messages
        } catch RestClientError.httpError(let statusCode) {
            print("DEBUG: HTTP Error \(statusCode) when fetching messages")
            throw MessageGatewayError.requestFailed(statusCode)
        }
    }

    func markMessagesAsDelivered(messageIds: [UUID], for username: String) async throws {
        let request = MarkDeliveredRequest(
            user_id: username,
            message_ids: messageIds
        )

        do {
            try await post(request, to: "/messages/mark-delivered")
        } catch RestClientError.httpError(let statusCode) {
            throw MessageGatewayError.requestFailed(statusCode)
        }
    }
}
