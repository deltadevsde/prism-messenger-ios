//
//  PresenceService.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation
import SwiftUI
import os

private let log = Log.presence

@Observable @MainActor
class PresenceService {
    private let presenceFetchGateway: PresenceFetchGateway
    private let presenceRtcGateway: PresenceRtcGateway

    /// Dictionary mapping account IDs to their current presence status
    /// Direct property access enables @Observable reactivity in SwiftUI views
    private(set) var presenceStatuses: [UUID: PresenceStatus] = [:]

    /// Cache timeout for presence statuses (in seconds)
    private let cacheTimeout: TimeInterval = 300.0

    /// Timestamps for when presence statuses were last fetched
    private var lastFetchTimestamps: [UUID: Date] = [:]

    /// Current user's presence status
    private(set) var currentUserStatus: PresenceStatus = PresenceStatus.offline

    init(
        presenceFetchGateway: PresenceFetchGateway,
        presenceRtcGateway: PresenceRtcGateway
    ) {
        self.presenceFetchGateway = presenceFetchGateway
        self.presenceRtcGateway = presenceRtcGateway
        setupPresenceHandler()
    }

    // MARK: - Public Methods

    /// Set up the handler for incoming presence changes
    func setupPresenceHandler() {
        presenceRtcGateway.handlePresenceChanges {
            [weak self] (accountId: UUID, status: PresenceStatus) in
            await MainActor.run {
                self?.handlePresenceChange(for: accountId, status: status)
            }
        }
    }

    /// Get presence status for a specific account
    /// - Parameter accountId: The account ID to get presence for
    /// - Returns: The presence status, or nil if not available
    func getPresenceStatus(for accountId: UUID) -> PresenceStatus? {
        return presenceStatuses[accountId]
    }

    /// Fetch presence status for a specific account
    /// Uses cache if available and not expired, otherwise fetches from server
    /// - Parameter accountId: The account ID to fetch presence for
    func loadPresenceStatus(for accountId: UUID) async {
        // Check if we have cached data that's still valid
        if presenceStatuses[accountId] != nil,
            let lastFetch = lastFetchTimestamps[accountId],
            Date().timeIntervalSince(lastFetch) < cacheTimeout
        {
            log.debug("Using cached presence status for \(accountId)")
            return
        }

        do {
            let status = try await presenceFetchGateway.fetchPresenceStatus(for: accountId)
            presenceStatuses[accountId] = status
            lastFetchTimestamps[accountId] = Date()
            log.debug("Fetched presence status for \(accountId)")
        } catch {
            log.error("Failed to fetch presence status for \(accountId): \(error)")
            // Set offline as fallback if fetch fails
            if presenceStatuses[accountId] == nil {
                presenceStatuses[accountId] = PresenceStatus.offline
            }
        }
    }

    /// Update the current user's presence status
    /// - Parameters:
    ///   - accountId: The current user's account ID
    ///   - status: The new presence status to set
    func updateCurrentUserStatus(for accountId: UUID, status: PresenceStatus) async {
        do {
            try await presenceRtcGateway.sendPresenceStatus(for: accountId, status: status)
            currentUserStatus = status
            // Also update in local cache
            presenceStatuses[accountId] = status
            lastFetchTimestamps[accountId] = Date()
            log.debug("Updated current user presence status")
        } catch {
            log.error("Failed to update presence status")
        }
    }

    // MARK: - Private Methods

    /// Handle incoming presence changes from other users
    /// - Parameters:
    ///   - accountId: The account ID whose presence status changed
    ///   - status: The new presence status
    private func handlePresenceChange(for accountId: UUID, status: PresenceStatus) {
        log.debug("Received presence change for account")
        presenceStatuses[accountId] = status
        lastFetchTimestamps[accountId] = Date()
    }
}
