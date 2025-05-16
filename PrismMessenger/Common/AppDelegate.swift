//
//  AppDelegate.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import SwiftUI

class AppDelegate: NSObject {

    var pushNotificationDelegate: PushNotificationDelegate?

    var messageService: MessageService?

    func setServices(
        pushNotificationDelegate: PushNotificationDelegate?,
        messageService: MessageService,
    ) {
        self.pushNotificationDelegate = pushNotificationDelegate
        self.messageService = messageService
    }
}

extension AppDelegate: UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        pushNotificationDelegate?.didRegisterForRemoteNotifications(withDeviceToken: deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        pushNotificationDelegate?.didFailToRegisterForRemoteNotifications(withError: error)
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
