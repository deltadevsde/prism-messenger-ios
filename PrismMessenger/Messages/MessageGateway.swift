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

/// Protocol for sending messages and managing delivery status
protocol MessageSenderGateway {
    /// Sends a message to another user
    /// - Parameters:
    ///   - message: The encrypted DoubleRatchetMessage to send
    ///   - recipientId: The recipient's ID
    /// - Returns: The server's response with message ID and timestamp
    func sendMessage(_ message: DoubleRatchetMessage, to recipientId: UUID)
        async throws -> MessageReceipt

    /// Marks messages as delivered on the server
    /// - Parameters:
    ///   - messageIds: Array of message IDs to mark as delivered
    func markMessagesAsDelivered(messageIds: [UUID]) async throws
}

/// Protocol for receiving messages in real-time
protocol MessageReceiverGateway {
    /// Registers a callback to receive incoming messages in real-time (for WebSocket)
    /// - Parameter handler: A closure that will be called when a new message arrives
    ///   - message: The received message
    func handleIncomingMessages(_ handler: @escaping (ReceivedMessage) async throws -> Void)
}
