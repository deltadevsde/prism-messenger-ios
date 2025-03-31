//
//  ConversationTests.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Testing
@testable import PrismMessenger
import Foundation

final class ConversationTests {

    var appContext: AppContext!

    init() async {
        appContext = await AppContext.forPreview()
    }

    @Test func twoPeopleChattingWithEachOther() async throws {
        // Simulate two registered users
        try! await appContext.registrationService.registerNewUser(username: "Bob")
        try! await appContext.registrationService.registerNewUser(username: "Alice")

        // Alice starts a chat with Bob
        await appContext.userService.selectAccount(username: "Alice")
        let chatAlice = try await appContext.chatService.startChat(with: "Bob")
        try await appContext.chatService.sendMessage(content: "Hello Bob", in: chatAlice)

        // Bob receives the message and answers
        await appContext.userService.selectAccount(username: "Bob")
        try await appContext.messageService.fetchAndProcessMessages()
        let chatBob = try await appContext.chatService.getChat(with: "Alice")!
        try await appContext.chatService.sendMessage(content: "Hello Alice", in: chatBob)

        // Alice receives Bob's answer
        await appContext.userService.selectAccount(username: "Alice")
        try await appContext.messageService.fetchAndProcessMessages()

        // repeat multiple times
        for i in 0..<5 {
            // Alice sends message to Bob
            try await appContext.chatService.sendMessage(content: "What up Bob? \(i)", in: chatAlice)
            try await Task.sleep(for: .milliseconds(100))

            // Bob receives and answers
            await appContext.userService.selectAccount(username: "Bob")
            try await appContext.messageService.fetchAndProcessMessages()
            try await appContext.chatService.sendMessage(content: "What up Alice? \(i)", in: chatBob)
            try await Task.sleep(for: .milliseconds(100))

            // Alice receives
            await appContext.userService.selectAccount(username: "Alice")
            try await appContext.messageService.fetchAndProcessMessages()
        }

        // Ensure both chats have 13 messages:
        // 1 msg for init "Chat established securely ..."
        // 2 msgs (1 each participant) to start conversation "Hello ..."
        // 10 msgs (5 each participant) back and forth "What up ..."
        #expect(chatAlice.messages.count == 13)
        #expect(chatBob.messages.count == 13)
    }
}
