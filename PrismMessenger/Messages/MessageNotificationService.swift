//
//  MessageNotificationService.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation
import UserNotifications

private let log = Log.messages

enum MessageNotificationError: Error {
    case missingAuthorization
    case sendingFailed
}

enum MessageNotificationCategory: String {
    case message = "message"
}

@MainActor
class MessageNotificationService {
    private let router: NavigationRouter
    private let scenePhaseRepository: ScenePhaseRepository
    private let notificationCenter: NotificationCenter
    private let chatRepository: ChatRepository

    init(
        router: NavigationRouter,
        scenePhaseRepository: ScenePhaseRepository,
        notificationCenter: NotificationCenter,
        chatRepository: ChatRepository
    ) {
        self.router = router
        self.scenePhaseRepository = scenePhaseRepository
        self.notificationCenter = notificationCenter
        self.chatRepository = chatRepository
    }

    func potentiallySendNotification(for message: Message) async throws {
        guard scenePhaseRepository.currentPhase == .active else {
            // When inactive, send notification in every case
            do {
                try await sendNotification(for: message)
            } catch {
                log.warning("Failed to send message notification: \(error)")
            }
            return
        }

        // When active, check whether we are already in the chat related to the message
        if case .chat(let activeChat) = router.activeRoute, activeChat == message.chat {
            return
        }

        // When active and not in the chat already
        try await sendNotification(for: message)
    }

    private func sendNotification(for message: Message) async throws {
        guard
            try await notificationCenter.requestAuthorization(options: [
                .alert, .badge, .sound,
            ])
        else {
            throw MessageNotificationError.missingAuthorization
        }

        let content = UNMutableNotificationContent()
        content.title = message.chat?.displayName ?? "New message"
        content.body = message.content
        content.sound = .default
        content.categoryIdentifier = MessageNotificationCategory.message.rawValue

        let identifier = (message.chat?.id ?? UUID()).uuidString
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)

        do {
            log.debug("Adding message notification: \(request)")
            try await notificationCenter.add(request)
        } catch {
            log.error("Unable to submit message notification: \(error)")
            throw MessageNotificationError.sendingFailed
        }
    }

    func handleMessageNotificationResponse(_ response: UNNotificationResponse) async {
        let identifier = response.notification.request.identifier

        guard let chatId = UUID(uuidString: identifier) else {
            log.error("Failed to read chat ID \(identifier) from notification response")
            return
        }

        guard let chat = try? await chatRepository.getChat(withId: chatId) else {
            log.error("Failed to fetch chat \(chatId) while handling message notification response")
            return
        }

        router.navigateTo(.chat(chat))
    }
}
