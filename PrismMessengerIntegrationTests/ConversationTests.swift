//
//  ConversationTests.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation
import Testing

@testable import PrismMessenger

@MainActor
final class ConversationTests {

    var appContextAlice: AppContext!
    var appContextBob: AppContext!

    init() async {
        // Simulate two registered users
        (appContextAlice, appContextBob) = await AppContextFactory.twoForTest()

        try! await appContextAlice.registrationService.registerNewUser(username: "Alice")
        try! await appContextBob.registrationService.registerNewUser(username: "Bob")

        await startApp(appContext: appContextAlice)
        await startApp(appContext: appContextBob)
    }

    @Test func twoPeopleChattingWithEachOther() async throws {
        let aliceId = appContextAlice.userService.currentUser!.id

        // Alice starts a chat with Bob
        let chatAlice = try await appContextAlice.chatService.startChat(with: "Bob")
        let message1 = try await appContextAlice.chatService.sendMessage(
            content: "Hello Bob",
            in: chatAlice
        )

        // Bob receives the message and answers
        let chatBob = try await expectEventuallyNonNil {
            try await self.appContextBob.chatService.getChat(with: aliceId)
        }
        let message2 = try await appContextBob.chatService.sendMessage(
            content: "Hello Alice",
            in: chatBob
        )

        // Wait for Alice to receive Bobs answer
        try await expectEventually(toEqual: 2) {
            chatAlice.messages.count
        }

        // repeat multiple times
        for i in 0..<5 {
            // Alice sends message to Bob
            let alicesMessage = try await appContextAlice.chatService.sendMessage(
                content: "What up Bob? \(i)",
                in: chatAlice
            )

            // Bob receives and answers
            let bobsMessage = try await appContextBob.chatService.sendMessage(
                content: "What up Alice? \(i)",
                in: chatBob
            )

            // Ensure both chats have correct number of messages:
            // 2 msgs (1 each participant) to start conversation "Hello ..."
            // another 2 msgs for each round of back and forth "What up ..."
            let expectedMessageCount = (i + 1) * 2 + 2
            try await expectEventually(toEqual: expectedMessageCount) {
                chatAlice.messages.count
            }
            try await expectEventually(toEqual: expectedMessageCount) {
                chatBob.messages.count
            }
        }
    }

    func expectEventually<T>(
        toEqual expectedValue: T,
        timeout: TimeInterval = 5.0,
        pollInterval: TimeInterval = 0.1,
        condition: @escaping () async throws -> T
    ) async throws where T: Equatable {
        let deadline = Date().addingTimeInterval(timeout)
        var lastError: Error?

        while Date() < deadline {
            do {
                let value = try await condition()
                if value == expectedValue {
                    return  // Success
                }
            } catch {
                lastError = error
            }

            try await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
        }

        // Timeout reached
        if let error = lastError {
            throw error
        } else {
            throw TestError.timeout(
                "Expected value \(expectedValue) not reached within \(timeout) seconds"
            )
        }
    }

    func expectEventuallyNonNil<T>(
        timeout: TimeInterval = 5.0,
        pollInterval: TimeInterval = 0.1,
        condition: @escaping () async throws -> T?
    ) async throws -> T {
        let deadline = Date().addingTimeInterval(timeout)
        var lastError: Error?

        while Date() < deadline {
            do {
                if let value = try await condition() {
                    return value  // Success - return the unwrapped value
                }
            } catch {
                lastError = error
            }

            try await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
        }

        // Timeout reached
        if let error = lastError {
            throw error
        } else {
            throw TestError.timeout("Expected non-nil value not received within \(timeout) seconds")
        }
    }
}

enum TestError: Error {
    case timeout(String)
}
