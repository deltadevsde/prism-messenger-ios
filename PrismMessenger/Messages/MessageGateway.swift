import CryptoKit
import Foundation

enum MessageGatewayError: Error {
    case requestFailed(Int)
}

protocol MessageReceipt {
    var messageId: UUID { get }
    var timestamp: UInt64 { get }
}

protocol ReceivedMessage {
    var messageId: UUID { get }
    var senderUsername: String { get }
    var recipientUsername: String { get }
    var message: DoubleRatchetMessage { get }
    var timestamp: UInt64 { get }
}

protocol MessageGateway {
    /// Sends a message to another user
    /// - Parameters:
    ///   - message: The encrypted DoubleRatchetMessage to send
    ///   - recipient: The recipient's username
    /// - Returns: The server's response with message ID and timestamp
    func sendMessage(_ message: DoubleRatchetMessage, to recipientUsername: String)
        async throws -> MessageReceipt

    /// Fetches all available messages for a user
    /// - Returns: Array of received messages
    func fetchMessages() async throws -> [ReceivedMessage]

    /// Marks messages as delivered on the server
    /// - Parameters:
    ///   - messageIds: Array of message IDs to mark as delivered
    func markMessagesAsDelivered(messageIds: [UUID]) async throws
}
