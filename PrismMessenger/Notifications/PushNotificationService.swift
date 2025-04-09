//
//  PushNotificationService.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import UserNotifications
import SwiftUI

private let log = Log.notifications

class PushNotificationService {

    private var tokenContinuation: CheckedContinuation<Data, Error>?

    // Get token using async/await
    func requestPushNotificationToken() async throws -> Data {
        log.debug("Requesting user auth for push notifications")
        let authGranted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])

        guard authGranted else {
            log.error("No authorization for notifications")
            throw NSError(domain: "PushNotification", code: 1, userInfo: [NSLocalizedDescriptionKey: "Notification permission denied"])
        }

        log.debug("Getting token through continuation")
        return try await withCheckedThrowingContinuation { continuation in
            self.tokenContinuation = continuation

            log.info("Registering for remote notifications")
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    // Called by the AppDelegate when token is received
    func didRegisterForRemoteNotifications(withDeviceToken deviceToken: Data) {
        tokenContinuation?.resume(returning: deviceToken)
        tokenContinuation = nil
    }

    // Called by the AppDelegate when registration fails
    func didFailToRegisterForRemoteNotifications(withError error: Error) {
        tokenContinuation?.resume(throwing: error)
        tokenContinuation = nil
    }
}
