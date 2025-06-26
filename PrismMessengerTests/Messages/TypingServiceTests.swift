//
//  TypingServiceTests.swift
//  PrismMessengerTests
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation
import Testing

@testable import PrismMessenger

@MainActor
struct TypingServiceTests {

    private var mockGateway: MockTypingGateway
    private var service: TypingService

    init() {
        mockGateway = MockTypingGateway()
        service = TypingService(
            typingGateway: mockGateway,
            incomingTypingTimeout: 0.3,
            outgoingTypingTimeout: 0.3
        )
        service.setupTypingStatusHandler()
    }

    // MARK: - Initial State Tests

    @Test func initialState() {
        #expect(service.typingAccounts.isEmpty)
    }

    @Test func isTypingReturnsFalseForUnknownAccount() {
        let accountId = UUID()
        #expect(!service.isTyping(accountId: accountId))
    }

    // MARK: - Typing Status Tests

    @Test func handleTypingStatusChange_StartTyping() async {
        let accountId = UUID()

        // Simulate receiving typing status
        await mockGateway.simulateTypingStatusReceived(accountId: accountId, isTyping: true)

        // Verify typing status is updated
        #expect(service.isTyping(accountId: accountId))
        #expect(service.typingAccounts.contains(accountId))
        #expect(service.typingAccounts == Set([accountId]))
    }

    @Test func handleTypingStatusChange_StopTyping() async {
        let accountId = UUID()

        // Start typing first
        await mockGateway.simulateTypingStatusReceived(accountId: accountId, isTyping: true)
        #expect(service.isTyping(accountId: accountId))

        // Stop typing
        await mockGateway.simulateTypingStatusReceived(accountId: accountId, isTyping: false)

        // Verify typing status is cleared
        #expect(!service.isTyping(accountId: accountId))
        #expect(!service.typingAccounts.contains(accountId))
        #expect(service.typingAccounts.isEmpty)
    }

    @Test func multipleAccountsTyping() async {
        let accountId1 = UUID()
        let accountId2 = UUID()
        let accountId3 = UUID()

        // Start typing for multiple accounts
        await mockGateway.simulateTypingStatusReceived(accountId: accountId1, isTyping: true)
        await mockGateway.simulateTypingStatusReceived(accountId: accountId2, isTyping: true)

        // Verify both are typing
        #expect(service.isTyping(accountId: accountId1))
        #expect(service.isTyping(accountId: accountId2))
        #expect(!service.isTyping(accountId: accountId3))

        #expect(service.typingAccounts == Set([accountId1, accountId2]))

        // Stop typing for one account
        await mockGateway.simulateTypingStatusReceived(accountId: accountId1, isTyping: false)

        // Verify only one is still typing
        #expect(!service.isTyping(accountId: accountId1))
        #expect(service.isTyping(accountId: accountId2))
        #expect(service.typingAccounts == Set([accountId2]))
    }

    // MARK: - Timeout Tests

    @Test func typingTimeout() async {
        let accountId = UUID()

        // Start typing
        await mockGateway.simulateTypingStatusReceived(accountId: accountId, isTyping: true)
        #expect(service.isTyping(accountId: accountId))

        // Wait for timeout (0.4 seconds to be safe)
        try? await Task.sleep(nanoseconds: 400_000_000)

        // Verify typing status is automatically cleared
        #expect(!service.isTyping(accountId: accountId))
        #expect(!service.typingAccounts.contains(accountId))
    }

    @Test func typingTimeoutCanceledOnNewTyping() async {
        let accountId = UUID()

        // Start typing
        await mockGateway.simulateTypingStatusReceived(accountId: accountId, isTyping: true)
        #expect(service.isTyping(accountId: accountId))

        // Wait 0.2 seconds
        try? await Task.sleep(nanoseconds: 200_000_000)

        // Send another typing status (should reset timer)
        await mockGateway.simulateTypingStatusReceived(accountId: accountId, isTyping: true)
        #expect(service.isTyping(accountId: accountId))

        // Wait another 0.2 seconds (total 0.4, but timer was reset)
        try? await Task.sleep(nanoseconds: 200_000_000)

        // Should still be typing since timer was reset
        #expect(service.isTyping(accountId: accountId))

        // Wait 0.2 more seconds to exceed the timeout from the reset
        try? await Task.sleep(nanoseconds: 200_000_000)

        // Now should be cleared
        #expect(!service.isTyping(accountId: accountId))
    }

    // MARK: - Handle User Typing Tests

    @Test func handleUserTyping_StartTyping() async {
        let accountId = UUID()

        // Handle user typing
        await service.handleUserTyping(for: accountId, isTyping: true)

        // Verify gateway method was called
        #expect(mockGateway.sendTypingStatusCalls.count == 1)
        let call = mockGateway.sendTypingStatusCalls[0]
        #expect(call.accountId == accountId)
        #expect(call.isTyping == true)
    }

    @Test func handleUserTyping_StopTyping() async {
        let accountId = UUID()

        // Start typing first
        await service.handleUserTyping(for: accountId, isTyping: true)
        #expect(mockGateway.sendTypingStatusCalls.count == 1)

        // Stop typing
        await service.handleUserTyping(for: accountId, isTyping: false)

        // Verify stop typing was sent
        #expect(mockGateway.sendTypingStatusCalls.count == 2)
        let stopCall = mockGateway.sendTypingStatusCalls[1]
        #expect(stopCall.accountId == accountId)
        #expect(stopCall.isTyping == false)
    }

    @Test func handleUserTyping_PreventSpam() async {
        let accountId = UUID()

        // Start typing multiple times
        await service.handleUserTyping(for: accountId, isTyping: true)
        await service.handleUserTyping(for: accountId, isTyping: true)
        await service.handleUserTyping(for: accountId, isTyping: true)

        // Should only send one typing status to prevent spam
        #expect(mockGateway.sendTypingStatusCalls.count == 1)
        let call = mockGateway.sendTypingStatusCalls[0]
        #expect(call.accountId == accountId)
        #expect(call.isTyping == true)
    }

    @Test func handleUserTyping_AutoTimeout() async {
        let accountId = UUID()

        // Start typing
        await service.handleUserTyping(for: accountId, isTyping: true)
        #expect(mockGateway.sendTypingStatusCalls.count == 1)

        // Wait for timeout (0.5 seconds to be safe)
        try? await Task.sleep(nanoseconds: 500_000_000)

        // Should automatically send stop typing
        #expect(mockGateway.sendTypingStatusCalls.count == 2)
        let stopCall = mockGateway.sendTypingStatusCalls[1]
        #expect(stopCall.accountId == accountId)
        #expect(stopCall.isTyping == false)
    }

    @Test func handleUserTyping_TimerReset() async {
        let accountId = UUID()

        // Start typing
        await service.handleUserTyping(for: accountId, isTyping: true)
        #expect(mockGateway.sendTypingStatusCalls.count == 1)

        // Wait 0.2 seconds
        try? await Task.sleep(nanoseconds: 200_000_000)

        // Continue typing (should reset timer but not send another update)
        await service.handleUserTyping(for: accountId, isTyping: true)
        #expect(mockGateway.sendTypingStatusCalls.count == 1)

        // Wait another 0.2 seconds (total 0.4, but timer was reset)
        try? await Task.sleep(nanoseconds: 200_000_000)

        // Should still be typing since timer was reset
        #expect(mockGateway.sendTypingStatusCalls.count == 1)

        // Wait another 0.2 seconds to exceed the timeout from the reset
        try? await Task.sleep(nanoseconds: 200_000_000)

        // Now should have sent stop typing
        #expect(mockGateway.sendTypingStatusCalls.count == 2)
        let stopCall = mockGateway.sendTypingStatusCalls[1]
        #expect(stopCall.accountId == accountId)
        #expect(stopCall.isTyping == false)
    }
}

// MARK: - Mock Gateway

private class MockTypingGateway: TypingGateway {

    struct SendTypingStatusCall {
        let accountId: UUID
        let isTyping: Bool
    }

    var sendTypingStatusCalls: [SendTypingStatusCall] = []
    private var typingHandler: ((UUID, Bool) async throws -> Void)?

    func sendTypingStatus(for accountId: UUID, isTyping: Bool) async throws {
        sendTypingStatusCalls.append(
            SendTypingStatusCall(accountId: accountId, isTyping: isTyping))
    }

    func handleTypingChanges(_ callback: @escaping (UUID, Bool) async throws -> Void) {
        typingHandler = callback
    }

    // Helper method for tests to simulate receiving typing updates
    @MainActor
    func simulateTypingStatusReceived(accountId: UUID, isTyping: Bool) async {
        do {
            try await typingHandler?(accountId, isTyping)
        } catch {
            Issue.record("Failed to handle typing update: \(error)")
        }
    }
}
