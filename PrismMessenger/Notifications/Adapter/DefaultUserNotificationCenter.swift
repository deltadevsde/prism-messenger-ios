//
//  DefaultUserNotificationCenter.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import UserNotifications

private let log = Log.notifications

/// Default UserNotificationCenter implementation wrapping UNUserNotificationCenter
class DefaultUserNotificationCenter: NSObject, UserNotificationCenter {

    private var handlers: [UserNotificationCategory: UserNotificationResponseHandler] = [:]

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func requestAuthorization() async throws -> Bool {
        return try await UNUserNotificationCenter.current().requestAuthorization(options: [
            .alert, .badge, .sound,
        ])
    }

    func post(_ request: UserNotificationRequest) async throws {
        let content = UNMutableNotificationContent()
        content.title = request.title
        content.body = request.content
        content.sound = request.sound.unNotificationSound
        content.categoryIdentifier = request.category.rawValue
        let request = UNNotificationRequest(
            identifier: request.identifier,
            content: content,
            trigger: nil
        )

        try await UNUserNotificationCenter.current().add(request)
    }

    func setResponseHandler(
        _ handler: any UserNotificationResponseHandler,
        for category: UserNotificationCategory
    ) {
        handlers[category] = handler
    }
}

extension DefaultUserNotificationCenter: UNUserNotificationCenterDelegate {

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let categoryId = response.notification.request.content.categoryIdentifier
        let identifier = response.notification.request.identifier
        guard
            let category = UserNotificationCategory(
                rawValue: response.notification.request.content.categoryIdentifier
            )
        else {
            log.error("Notification response of unknown category: \(categoryId)")
            completionHandler()
            return
        }

        let userNotificationResponse = UserNotificationResponse(
            identifier: identifier,
            category: category,
            actionIdentifier: response.actionIdentifier
        )

        Task { @MainActor in
            await self.handlers[category]?.handleNotificationResponse(userNotificationResponse)
            completionHandler()
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler:
            @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notifications when in foreground
        completionHandler([.banner, .sound, .badge])
    }
}
