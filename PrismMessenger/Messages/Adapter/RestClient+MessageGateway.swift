import Foundation

/// API request model for sending a message
struct SendMessageRequest: Encodable {
    var sender_id: String
    var recipient_id: String
    var message: DoubleRatchetMessage
}

/// API response when sending a message
struct SendMessageResponse: Decodable {
    var message_id: UUID
    var timestamp: UInt64
}

/// API model for a message received from the server
struct APIMessage: Decodable {
    var message_id: UUID
    var sender_id: String
    var recipient_id: String
    var message: DoubleRatchetMessage
    var timestamp: UInt64
}

/// API model for marking messages as delivered
struct MarkDeliveredRequest: Encodable {
    var user_id: String
    var message_ids: [UUID]
}

extension RestClient: MessageGateway {
    func sendMessage(_ message: DoubleRatchetMessage, from sender: String, to recipient: String)
        async throws -> SendMessageResponse
    {
        let request = SendMessageRequest(
            sender_id: sender,
            recipient_id: recipient,
            message: message
        )

        do {
            return try await post(request, to: "/messages/send")
        } catch RestClientError.httpError(let statusCode) {
            throw MessageGatewayError.requestFailed(statusCode)
        }
    }

    func fetchMessages(for username: String) async throws -> [APIMessage] {
        print("DEBUG: Fetching messages for \(username)")
        do {
            let messages: [APIMessage] = try await fetch(from: "/messages/get/\(username)")
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
