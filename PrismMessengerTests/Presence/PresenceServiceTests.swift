//
//  PresenceServiceTests.swift
//  PrismMessengerTests
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation
import Testing

@testable import PrismMessenger

@MainActor
struct PresenceServiceTests {

    private var mockFetchGateway: MockPresenceFetchGateway
    private var mockRtcGateway: MockPresenceRtcGateway
    private var service: PresenceService

    init() {
        mockFetchGateway = MockPresenceFetchGateway()
        mockRtcGateway = MockPresenceRtcGateway()
        service = PresenceService(
            presenceFetchGateway: mockFetchGateway,
            presenceRtcGateway: mockRtcGateway
        )
        service.setupPresenceHandler()
    }

    // MARK: - Fetch Tests

    @Test
    func fetchPresenceStatus_Success() async {
        // Given
        let accountId = UUID()
        let expectedStatus = PresenceStatus.online
        mockFetchGateway.mockPresenceStatus = expectedStatus

        // When
        await service.loadPresenceStatus(for: accountId)

        // Then
        let actualStatus = service.getPresenceStatus(for: accountId)
        #expect(actualStatus == expectedStatus)
        #expect(mockFetchGateway.fetchPresenceStatusCalled)
        #expect(mockFetchGateway.lastFetchedAccountId == accountId)
    }

    @Test
    func fetchPresenceStatus_Failure() async {
        // Given
        let accountId = UUID()
        mockFetchGateway.shouldThrowError = true

        // When
        await service.loadPresenceStatus(for: accountId)

        // Then
        let actualStatus = service.getPresenceStatus(for: accountId)
        #expect(actualStatus == PresenceStatus.offline)  // Should fallback to offline
    }

    @Test
    func fetchPresenceStatus_UsesCacheWhenValid() async {
        // Given
        let accountId = UUID()
        let expectedStatus = PresenceStatus.away
        mockFetchGateway.mockPresenceStatus = expectedStatus

        // When - First fetch
        await service.loadPresenceStatus(for: accountId)
        mockFetchGateway.fetchPresenceStatusCalled = false  // Reset

        // When - Second fetch immediately (should use cache)
        await service.loadPresenceStatus(for: accountId)

        // Then
        #expect(!mockFetchGateway.fetchPresenceStatusCalled)
        let actualStatus = service.getPresenceStatus(for: accountId)
        #expect(actualStatus == expectedStatus)
    }

    // MARK: - Send Tests

    @Test
    func updateCurrentUserStatus_Success() async {
        // Given
        let accountId = UUID()
        let newStatus = PresenceStatus.away

        // When
        await service.updateCurrentUserStatus(for: accountId, status: newStatus)

        // Then
        #expect(service.currentUserStatus == newStatus)
        #expect(mockRtcGateway.sendPresenceStatusCalled)
        #expect(mockRtcGateway.lastSentAccountId == accountId)
        #expect(mockRtcGateway.lastSentStatus == newStatus)

        // Should also update local cache
        let cachedStatus = service.getPresenceStatus(for: accountId)
        #expect(cachedStatus == newStatus)
    }

    @Test
    func updateCurrentUserStatus_Failure() async {
        // Given
        let accountId = UUID()
        let newStatus = PresenceStatus.online
        let originalStatus = service.currentUserStatus
        mockRtcGateway.shouldThrowError = true

        // When
        await service.updateCurrentUserStatus(for: accountId, status: newStatus)

        // Then
        #expect(service.currentUserStatus == originalStatus)  // Should not change on failure
    }

    // MARK: - Receive Tests

    @Test
    func handlePresenceChanges() async {
        // Given
        let accountId = UUID()
        let newStatus = PresenceStatus.online

        // When
        await mockRtcGateway.simulatePresenceChange(accountId: accountId, status: newStatus)

        // Then
        let actualStatus = service.getPresenceStatus(for: accountId)
        #expect(actualStatus == newStatus)
    }
}

// MARK: - Mock Implementations

class MockPresenceFetchGateway: PresenceFetchGateway {
    var mockPresenceStatus: PresenceStatus = PresenceStatus.offline
    var mockPresenceStatuses: [UUID: PresenceStatus] = [:]
    var shouldThrowError = false
    var fetchPresenceStatusCalled = false
    var lastFetchedAccountId: UUID?

    func fetchPresenceStatus(for accountId: UUID) async throws -> PresenceStatus {
        fetchPresenceStatusCalled = true
        lastFetchedAccountId = accountId

        if shouldThrowError {
            throw PresenceTestError.mockError
        }

        return mockPresenceStatuses[accountId] ?? mockPresenceStatus
    }
}

class MockPresenceRtcGateway: PresenceRtcGateway {
    private var callback: ((UUID, PresenceStatus) async throws -> Void)?
    var shouldThrowError = false
    var sendPresenceStatusCalled = false
    var lastSentAccountId: UUID?
    var lastSentStatus: PresenceStatus?

    func handlePresenceChanges(_ callback: @escaping (UUID, PresenceStatus) async throws -> Void) {
        self.callback = callback
    }

    func simulatePresenceChange(accountId: UUID, status: PresenceStatus) async {
        do {
            try await callback?(accountId, status)
        } catch {
            print("Mock callback error: \(error)")
        }
    }

    func sendPresenceStatus(for accountId: UUID, status: PresenceStatus) async throws {
        sendPresenceStatusCalled = true
        lastSentAccountId = accountId
        lastSentStatus = status

        if shouldThrowError {
            throw PresenceTestError.mockError
        }
    }
}

enum PresenceTestError: Error {
    case mockError
}
