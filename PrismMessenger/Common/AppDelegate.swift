//
//  AppDelegate.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import SwiftUI

class AppDelegate: NSObject, UIApplicationDelegate {

    var pushNotificationService: PushNotificationService?

    var messageService: MessageService?

    func setServices(
        pushNotificationService: PushNotificationService,
        messageService: MessageService
    ) {
        self.pushNotificationService = pushNotificationService
        self.messageService = messageService
    }

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
