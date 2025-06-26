//
//  PresenceGateway.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation

/// Status representing a user's presence state
enum PresenceStatus: String, Codable, CaseIterable {
    case online = "online"
    case away = "away"
    case offline = "offline"

    var displayText: String {
        switch self {
        case .online:
            return "Online"
        case .away:
            return "Away"
        case .offline:
            return "Offline"
        }
    }
}

/// Protocol for fetching presence status via REST API
protocol PresenceFetchGateway {
    /// Fetches the current presence status for a specific account
    /// - Parameter accountId: The ID of the account to fetch presence for
    /// - Returns: The current presence status of the account
    func fetchPresenceStatus(for accountId: UUID) async throws -> PresenceStatus
}

/// Protocol for real-time presence communication via WebSocket/RTC
protocol PresenceRtcGateway {
    /// Registers a callback to receive presence status updates from other users
    /// - Parameter callback: A closure that will be called when presence status changes
    ///   - accountId: The ID of the account whose presence status changed
    ///   - status: The new presence status of the account
    func handlePresenceChanges(_ callback: @escaping (UUID, PresenceStatus) async throws -> Void)

    /// Sends presence status update for the current user
    /// - Parameters:
    ///   - accountId: The ID of the account whose presence status changed
    ///   - status: The new presence status to broadcast
    func sendPresenceStatus(for accountId: UUID, status: PresenceStatus) async throws
}
