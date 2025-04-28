//
//  AppDelegate.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import SwiftUI

class AppDelegate: NSObject {

    var pushNotificationService: PushNotificationService?

    var messageService: MessageService?

    var messageNotificationService: MessageNotificationService?

    func setServices(
        pushNotificationService: PushNotificationService,
        messageService: MessageService,
        messageNotificationService: MessageNotificationService
    ) {
        self.pushNotificationService = pushNotificationService
        self.messageService = messageService
        self.messageNotificationService = messageNotificationService

        UNUserNotificationCenter.current().delegate = self
    }
}

extension AppDelegate: UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        pushNotificationService?.didRegisterForRemoteNotifications(withDeviceToken: deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        pushNotificationService?.didFailToRegisterForRemoteNotifications(withError: error)
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        Task {
            do {
                if let messageService = messageService {
                    try await messageService.fetchAndProcessMessages()
                    completionHandler(.newData)
                } else {
                    completionHandler(.noData)
                }
            } catch {
                completionHandler(.failed)
            }
        }
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let categordyId = response.notification.request.content.categoryIdentifier

        guard
            let category = MessageNotificationCategory(
                rawValue: response.notification.request.content.categoryIdentifier
            )
        else {
            Log.notifications.error("Notification response of unknown category: \(categordyId)")
            return
        }

        Task.detached { @MainActor in
            switch category {
            case .message:
                await self.messageNotificationService?.handleMessageNotificationResponse(response)
            }

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
