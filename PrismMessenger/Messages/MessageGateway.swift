import CryptoKit
import Foundation

enum MessageGatewayError: Error {
    case requestFailed(Int)
    case invalidResponse
}

protocol MessageReceipt {
    var messageId: UUID { get }
    var timestamp: UInt64 { get }
}

protocol ReceivedMessage {
    var messageId: UUID { get }
    var senderId: UUID { get }
    var recipientId: UUID { get }
    var message: DoubleRatchetMessage { get }
    var timestamp: UInt64 { get }
}

protocol MessageGateway {
    /// Sends a message to another user
    /// - Parameters:
    ///   - message: The encrypted DoubleRatchetMessage to send
    ///   - recipientId: The recipient's ID
    /// - Returns: The server's response with message ID and timestamp
    func sendMessage(_ message: DoubleRatchetMessage, to recipientId: UUID)
        async throws -> MessageReceipt

    /// Fetches all available messages for a user
    /// - Returns: Array of received messages
    func fetchMessages() async throws -> [ReceivedMessage]

    /// Marks messages as delivered on the server
    /// - Parameters:
    ///   - messageIds: Array of message IDs to mark as delivered
    func markMessagesAsDelivered(messageIds: [UUID]) async throws
}
