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
    var senderId: String { get }
    var recipientId: String { get }
    var message: DoubleRatchetMessage { get }
    var timestamp: UInt64 { get }
}

protocol MessageGateway {
    /// Sends a message to another user
    /// - Parameters:
    ///   - message: The encrypted DoubleRatchetMessage to send
    ///   - sender: The sender's username
    ///   - recipient: The recipient's username
    /// - Returns: The server's response with message ID and timestamp
    func sendMessage(_ message: DoubleRatchetMessage, from sender: String, to recipient: String)
        async throws -> MessageReceipt

    /// Fetches all available messages for a user
    /// - Parameter username: The username to fetch messages for
    /// - Returns: Array of received messages
    func fetchMessages(for username: String) async throws -> [ReceivedMessage]

    /// Marks messages as delivered on the server
    /// - Parameters:
    ///   - messageIds: Array of message IDs to mark as delivered
    ///   - username: The username marking the messages as delivered
    func markMessagesAsDelivered(messageIds: [UUID], for username: String) async throws
}
