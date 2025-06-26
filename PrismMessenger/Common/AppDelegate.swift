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
    var connectionService: ConnectionService?

    func setServices(
        pushNotificationDelegate: PushNotificationDelegate?,
        messageService: MessageService,
        connectionService: ConnectionService
    ) {
        self.pushNotificationDelegate = pushNotificationDelegate
        self.messageService = messageService
        self.connectionService = connectionService
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
                if let connectionService = connectionService {
                    // Establish WebSocket connection for background message processing
                    // Messages will be delivered via the WebSocket callback automatically
                    await connectionService.handleBackgroundPushNotification()
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
