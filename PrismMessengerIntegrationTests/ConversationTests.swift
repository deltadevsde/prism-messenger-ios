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

        try await Task.sleep(for: .milliseconds(100))

        // Bob receives the message and answers
        let chatBob = try await appContextBob.chatService.getChat(with: aliceId)!
        let message2 = try await appContextBob.chatService.sendMessage(
            content: "Hello Alice",
            in: chatBob
        )

        try await Task.sleep(for: .milliseconds(100))

        // repeat multiple times
        for i in 0..<5 {
            // Alice sends message to Bob
            let alicesMessage = try await appContextAlice.chatService.sendMessage(
                content: "What up Bob? \(i)",
                in: chatAlice
            )
            try await Task.sleep(for: .milliseconds(100))

            // Bob receives and answers
            let bobsMessage = try await appContextBob.chatService.sendMessage(
                content: "What up Alice? \(i)",
                in: chatBob
            )
            try await Task.sleep(for: .milliseconds(100))
        }

        // Ensure both chats have 12 messages:
        // 2 msgs (1 each participant) to start conversation "Hello ..."
        // 10 msgs (5 each participant) back and forth "What up ..."
        #expect(chatAlice.messages.count == 12)
        #expect(chatBob.messages.count == 12)
    }

}
