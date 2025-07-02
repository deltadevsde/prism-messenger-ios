//
//  TypingService.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation
import SwiftUI

private let log = Log.messages

@Observable @MainActor
class TypingService {
    private let typingGateway: TypingGateway

    /// Set of account IDs that are currently typing
    /// Direct property access enables @Observable reactivity in SwiftUI views
    private(set) var typingAccounts: Set<UUID> = []

    /// Timer to automatically clear typing status after a timeout
    private var typingTimers: [UUID: Timer] = [:]

    /// Timeout duration for incoming typing status from other users (in seconds)
    private let incomingTypingTimeout: TimeInterval

    /// Timeout duration for user's own typing inactivity (in seconds)
    private let outgoingTypingTimeout: TimeInterval

    /// Timer to automatically send a "stopped typing" message after inactivity
    private var outgoingTypingTimer: Timer?

    /// Current outgoing typing state for each account
    private var outgoingTypingState: [UUID: Bool] = [:]

    init(
        typingGateway: TypingGateway,
        incomingTypingTimeout: TimeInterval = 5.0,
        outgoingTypingTimeout: TimeInterval = 2.0
    ) {
        self.typingGateway = typingGateway
        self.incomingTypingTimeout = incomingTypingTimeout
        self.outgoingTypingTimeout = outgoingTypingTimeout
    }

    // MARK: - Public Methods

    /// Set up the handler for incoming typing changes
    func setupTypingStatusHandler() {
        typingGateway.handleTypingChanges { [weak self] accountId, isTyping in
            log.debug("Received typing update for account \(accountId): \(isTyping)")
            self?.updateTypingStatus(for: accountId, isTyping: isTyping)
        }
    }

    /// Check if a specific account is currently typing
    /// - Parameter accountId: The account ID to check
    /// - Returns: True if the account is typing, false otherwise
    /// - Note: For @Observable reactivity, prefer direct access: `service.typingAccounts.contains(accountId)`
    func isTyping(accountId: UUID) -> Bool {
        return typingAccounts.contains(accountId)
    }

    /// Handle user typing state changes with automatic timeout
    /// Call this when the user starts or stops typing in the UI
    /// - Parameters:
    ///   - accountId: The account ID to send typing status for
    ///   - isTyping: Whether the user is currently typing
    func handleUserTyping(for accountId: UUID, isTyping: Bool) async {
        // Cancel existing timer
        outgoingTypingTimer?.invalidate()
        outgoingTypingTimer = nil

        if isTyping {
            // Only send if not already typing to avoid spam
            let wasAlreadyTyping = outgoingTypingState[accountId] ?? false
            if !wasAlreadyTyping {
                outgoingTypingState[accountId] = true
                await sendTypingStatus(for: accountId, isTyping: true)
            }

            // Set timer to automatically stop typing after 2 seconds of inactivity
            outgoingTypingTimer =
                Timer
                .scheduledTimer(withTimeInterval: outgoingTypingTimeout, repeats: false) {
                    [weak self] _ in
                    Task { @MainActor in
                        await self?.stopUserTyping(for: accountId)
                    }
                }
        } else {
            await stopUserTyping(for: accountId)
        }
    }

    /// Set outgoing typing status to false for a specific account
    /// - Parameter accountId: The account ID to stop typing for
    private func stopUserTyping(for accountId: UUID) async {
        let wasTyping = outgoingTypingState[accountId] ?? false
        if wasTyping {
            outgoingTypingState[accountId] = false
            await sendTypingStatus(for: accountId, isTyping: false)
        }
    }

    /// Send typing status for a specific account
    /// - Parameters:
    ///   - accountId: The account ID to send typing status for
    ///   - isTyping: Whether the user is currently typing
    private func sendTypingStatus(for accountId: UUID, isTyping: Bool) async {
        do {
            try await typingGateway.sendTypingStatus(for: accountId, isTyping: isTyping)
            log.debug("Sent typing status for account \(accountId): \(isTyping)")
        } catch {
            log.error("Failed to send typing status for account \(accountId): \(error)")
        }
    }

    /// Update typing status for an account and manage timeout timers
    /// - Parameters:
    ///   - accountId: The account ID to update
    ///   - isTyping: Whether the account is currently typing
    private func updateTypingStatus(for accountId: UUID, isTyping: Bool) {
        // Cancel existing timer for this account
        typingTimers[accountId]?.invalidate()
        typingTimers[accountId] = nil

        if isTyping {
            // Add account to typing set
            typingAccounts.insert(accountId)

            // Set up timeout timer to automatically clear typing status
            let timer = Timer.scheduledTimer(
                withTimeInterval: incomingTypingTimeout, repeats: false
            ) {
                [weak self] _ in
                Task { @MainActor in
                    self?.handleTypingTimeout(for: accountId)
                }
            }
            typingTimers[accountId] = timer
        } else {
            // Remove account from typing set
            typingAccounts.remove(accountId)
        }
    }

    /// Handle typing timeout for an account
    /// - Parameter accountId: The account ID that timed out
    private func handleTypingTimeout(for accountId: UUID) {
        log.debug("Typing status timed out for account \(accountId)")
        typingAccounts.remove(accountId)
        typingTimers.removeValue(forKey: accountId)
    }

    // Note: Timers will be automatically cleaned up when the service is deallocated
    // since this service is expected to live for the app's lifetime
}
