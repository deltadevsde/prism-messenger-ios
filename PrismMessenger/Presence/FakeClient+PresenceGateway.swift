//
//  FakeClient+PresenceGateway.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation

extension FakeClient: PresenceFetchGateway, PresenceRtcGateway {

    // MARK: - PresenceFetchGateway

    func fetchPresenceStatus(for accountId: UUID) async throws -> PresenceStatus {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 second

        // Return a fake status based on account ID for consistent testing
        let hashValue = abs(accountId.hashValue)
        let statusIndex = hashValue % PresenceStatus.allCases.count
        return PresenceStatus.allCases[statusIndex]
    }

    func fetchPresenceStatuses(for accountIds: [UUID]) async throws -> [UUID: PresenceStatus] {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 200_000_000)  // 0.2 seconds

        var result: [UUID: PresenceStatus] = [:]
        for accountId in accountIds {
            let hashValue = abs(accountId.hashValue)
            let statusIndex = hashValue % PresenceStatus.allCases.count
            result[accountId] = PresenceStatus.allCases[statusIndex]
        }

        return result
    }

    // MARK: - PresenceRtcGateway

    func handlePresenceChanges(_ callback: @escaping (UUID, PresenceStatus) async throws -> Void) {
        // In a real fake implementation, you might want to simulate periodic presence changes
        // For now, this optionally simulates some initial presence changes for testing
        Task {
            try await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second

            // Simulate a random user coming online
            let randomAccountId = UUID()
            try await callback(randomAccountId, .online)

            try await Task.sleep(nanoseconds: 3_000_000_000)  // 3 seconds

            // Simulate the same user going away
            try await callback(randomAccountId, .away)
        }
    }

    func sendPresenceStatus(for accountId: UUID, status: PresenceStatus) async throws {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 50_000_000)  // 0.05 seconds

        // In a real implementation, this would echo back the presence change
        // to simulate server behavior, but we can't store callbacks in extensions
        print("FakeClient: Sent presence status \(status) for account \(accountId)")
    }

    // MARK: - Testing Helpers

    /// Manually trigger a presence change for testing
    func simulatePresenceChange(for accountId: UUID, status: PresenceStatus) async throws {
        // This would need to be implemented using a proper callback storage mechanism
        // For now, this is a placeholder for testing purposes
    }
}
