//
//  TypingGateway.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation

/// Protocol for sending typing updates for the current user
protocol TypingGateway {
    /// Sends typing state for the current user
    /// - Parameters:
    ///   - accountId: The ID of the account towards which the current user's typing state changed
    ///   - isTyping: Whether the current user is currently typing (true) or stopped typing (false) to the specified account
    func sendTypingStatus(for accountId: UUID, isTyping: Bool) async throws

    /// Registers a callback to receive typing updates from other users
    /// - Parameter callback: A closure that will be called when typing state changes
    ///   - accountId: The ID of the account whose typing state changed
    ///   - isTyping: Whether the account is currently typing (true) or stopped typing (false)
    func handleTypingChanges(_ callback: @escaping (UUID, Bool) async throws -> Void)
}
