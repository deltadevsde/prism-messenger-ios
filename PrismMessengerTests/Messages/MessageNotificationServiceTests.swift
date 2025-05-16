//
//  MessageNotificationServiceTests.swift
//  PrismMessengerTests
//
//  Copyright © 2025 prism. All rights reserved.
//

import Testing
import UserNotifications

@testable import PrismMessenger

private let log = Log.messages

enum TestError: Error {
    case someError
}

/// Mock implementation of ChatRepository for testing
class MockChatRepository: ChatRepository {
    var getChatWithIdCallCount = 0
    var getChatWithIdReturnValue: Chat? = nil
    var getChatWithIdError: Error? = nil

    func getAllChats() async throws -> [Chat] {
        return []
    }

    func getChat(withId id: UUID) async throws -> Chat? {
        getChatWithIdCallCount += 1

        if let error = getChatWithIdError {
            throw error
        }

        return getChatWithIdReturnValue
    }

    func getChat(withParticipant participantId: UUID)
        async throws -> Chat?
    {
        return nil
    }

    func saveChat(_ chat: Chat) async throws {}

    func deleteChat(_ chat: Chat) async throws {}
}

@MainActor
final class MessageNotificationServiceTests {

    private let router: NavigationRouter
    private let scenePhaseRepository: ScenePhaseRepository
    private let notificationCenter: UserNotificationCenter
    private let chatRepository: MockChatRepository

    private let service: MessageNotificationService

    init() async throws {
        router = NavigationRouter()
        scenePhaseRepository = ScenePhaseRepository()
        notificationCenter = FakeUserNotificationCenter()
        chatRepository = MockChatRepository()

        service = MessageNotificationService(
            router: router,
            scenePhaseRepository: scenePhaseRepository,
            notificationCenter: notificationCenter,
            chatRepository: chatRepository
        )
        notificationCenter.setResponseHandler(service, for: .message)
    }

    // MARK: - Tests

    @Test
    func sendAndReceiveNotificationWhileInForeground() async throws {
        // Set up test message in a simulated chat
        let message = createTestMessage()
        chatRepository.getChatWithIdReturnValue = message.chat

        // Simulate app is in foreground and the current chat is open
        scenePhaseRepository.currentPhase = .active
        router.path = [.chat(message.chat!)]

        // Ensure no notification is sent and we remain on the old route
        await service.potentiallySendNotification(for: message)

        #expect(chatRepository.getChatWithIdCallCount == 0, "Should not fetch the chat")
        #expect(router.path == [.chat(message.chat!)], "Should not navigate")

        // Simulate app is in foreground and another chat is open
        let anotherMessage = createTestMessage()

        scenePhaseRepository.currentPhase = .active
        router.path = [.chat(anotherMessage.chat!)]

        // Ensure a notification is sent and the route changes to the chat of the notification
        await service.potentiallySendNotification(for: message)

        #expect(chatRepository.getChatWithIdCallCount == 1, "Should fetch the chat")
        #expect(router.path == [.chat(message.chat!)], "Should navigate")
    }

    @Test
    func sendAndReceiveNotificationWhileInBackground() async throws {
        // Set up test message in a simulated chat
        let message = createTestMessage()
        chatRepository.getChatWithIdReturnValue = message.chat

        // Simulate app is in background and the current chat is open
        scenePhaseRepository.currentPhase = .background
        router.path = [.chat(message.chat!)]

        // Ensure a notification is sent and the route remains at the current chat
        await service.potentiallySendNotification(for: message)

        #expect(chatRepository.getChatWithIdCallCount == 1, "Should fetch the chat")
        #expect(router.path == [.chat(message.chat!)], "Should not navigate")

        // Simulate app is in background and another chat is open
        let anotherMessage = createTestMessage()

        scenePhaseRepository.currentPhase = .background
        router.path = [.chat(anotherMessage.chat!)]

        // Ensure a notification is sent and the route changes to the chat of the notification
        await service.potentiallySendNotification(for: message)

        #expect(chatRepository.getChatWithIdCallCount == 2, "Should fetch the chat")
        #expect(router.path == [.chat(message.chat!)], "Should navigate")
    }

    @Test
    func sendNotificationErrors() async throws {
        // Set up test message in a simulated chat
        let message = createTestMessage()
        scenePhaseRepository.currentPhase = .active

        // Simulate chatRepository errors
        chatRepository.getChatWithIdError = TestError.someError

        // Ensure no error is thrown but we remain on the old route
        await self.service.potentiallySendNotification(for: message)

        #expect(chatRepository.getChatWithIdCallCount == 1, "Should fetch the chat")
        #expect(router.path == [], "Should not navigate")
    }

    // MARK: - Test Setup Helpers

    private func createTestMessage(content: String = "Test message") -> Message {
        let message = Message(content: content, isFromMe: false)
        let chat = Chat(
            participantId: UUID(),
            displayName: "Test User",
            doubleRatchetSession: Data()
        )
        message.chat = chat
        return message
    }
}
