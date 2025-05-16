//
//  ConversationTests.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Testing
@testable import PrismMessenger
import Foundation

@MainActor
final class ConversationTests {

    var appContextAlice: AppContext!
    var appContextBob: AppContext!

    init() async {
        (appContextAlice, appContextBob) = await AppContextFactory.twoForTest()
    }

    @Test func twoPeopleChattingWithEachOther() async throws {
        // Simulate two registered users
        try! await appContextAlice.registrationService.registerNewUser(username: "Alice")
        try! await appContextBob.registrationService.registerNewUser(username: "Bob")

        let aliceId = appContextAlice.userService.currentUser!.id


        // Alice starts a chat with Bob
        let chatAlice = try await appContextAlice.chatService.startChat(with: "Bob")
        try await appContextAlice.chatService.sendMessage(content: "Hello Bob", in: chatAlice)

        // Bob receives the message and answers
        try await appContextBob.messageService.fetchAndProcessMessages()
        let chatBob = try await appContextBob.chatService.getChat(with: aliceId)!
        try await appContextBob.chatService.sendMessage(content: "Hello Alice", in: chatBob)

        // Alice receives Bob's answer
        try await appContextAlice.messageService.fetchAndProcessMessages()

        // repeat multiple times
        for i in 0..<5 {
            // Alice sends message to Bob
            try await appContextAlice.chatService.sendMessage(content: "What up Bob? \(i)", in: chatAlice)
            try await Task.sleep(for: .milliseconds(100))

            // Bob receives and answers
            try await appContextBob.messageService.fetchAndProcessMessages()
            try await appContextBob.chatService.sendMessage(content: "What up Alice? \(i)", in: chatBob)
            try await Task.sleep(for: .milliseconds(100))

            // Alice receives
            try await appContextAlice.messageService.fetchAndProcessMessages()
        }

        // Ensure both chats have 12 messages:
        // 2 msgs (1 each participant) to start conversation "Hello ..."
        // 10 msgs (5 each participant) back and forth "What up ..."
        #expect(chatAlice.messages.count == 12)
        #expect(chatBob.messages.count == 12)
    }

    
}
