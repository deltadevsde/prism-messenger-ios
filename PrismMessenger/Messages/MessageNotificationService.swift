//
//  MessageNotificationService.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation
import UserNotifications

private let log = Log.messages

@MainActor
class MessageNotificationService {
    private let router: NavigationRouter
    private let scenePhaseRepository: ScenePhaseRepository
    private let notificationCenter: UserNotificationCenter
    private let chatRepository: ChatRepository

    init(
        router: NavigationRouter,
        scenePhaseRepository: ScenePhaseRepository,
        notificationCenter: UserNotificationCenter,
        chatRepository: ChatRepository
    ) {
        self.router = router
        self.scenePhaseRepository = scenePhaseRepository
        self.notificationCenter = notificationCenter
        self.chatRepository = chatRepository
    }

    func potentiallySendNotification(for message: Message) async throws {
        // Skip notification if app is active and user is already in the relevant chat
        if scenePhaseRepository.currentPhase == .active,
            case .chat(let activeChat) = router.activeRoute,
            activeChat == message.chat
        {
            return
        }

        // Otherwise send notification
        guard
            try await notificationCenter.requestAuthorization()
        else {
            throw UserNotificationError.missingAuthorization
        }

        let request = UserNotificationRequest(
            identifier: (message.chat?.id ?? UUID()).uuidString,
            title: message.chat?.displayName ?? "New message",
            category: .message,
            sound: .default,
            content: message.content
        )

        do {
            log.debug("Adding chat notification for: \(request.title)")
            try await notificationCenter.post(request)
        } catch {
            log.error("Unable to submit message notification: \(error)")
            throw UserNotificationError.sendingFailed
        }
    }
}

extension MessageNotificationService: UserNotificationResponseHandler {

    func handleNotificationResponse(_ response: UserNotificationResponse) async {
        guard let chatId = UUID(uuidString: response.identifier) else {
            log.error("Failed to read chat ID \(response.identifier) from notification response")
            return
        }

        guard let chat = try? await chatRepository.getChat(withId: chatId) else {
            log.error("Failed to fetch chat \(chatId) while handling message notification response")
            return
        }

        router.openChat(chat)
    }
}
