//
//  ConversationTests.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Testing
@testable import PrismMessenger

final class ConversationTests {

    var appContext: AppContext!

    init() async {
        appContext = await AppContext.forPreview()
    }

    @Test func twoPeopleChattingWithEachOther() async throws {

        try! await appContext.registrationService.registerNewUser(username: "Bob")
        try! await appContext.registrationService.registerNewUser(username: "Alice")

        let chat = try await appContext.chatService.startChat(with: "Bob")

        for i in 0..<20 {
            try await appContext.chatService.sendMessage(content: "Hello \(i)", in: chat)
            try await Task.sleep(for: .milliseconds(100))
        }
    }
}
