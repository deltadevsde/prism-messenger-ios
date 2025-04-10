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

    // Timeout in seconds for push notification token registration
    private let tokenRegistrationTimeoutSeconds: UInt64 = 30

    private var tokenContinuation: CheckedContinuation<Data, Error>?

    // Get token using async/await
    func requestPushNotificationToken() async throws -> Data {
        log.debug("Requesting user auth for push notifications")
        let authGranted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])

        guard authGranted else {
            log.error("No authorization for notifications")
            throw NSError(domain: "PushNotification", code: 1, userInfo: [NSLocalizedDescriptionKey: "Notification permission denied"])
        }

        let settings = await UNUserNotificationCenter.current().notificationSettings()
        print("Notification settings: \(settings)")
        guard settings.authorizationStatus == .authorized else {
            throw NSError(
                domain: "PushNotification",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Notification permission not there"]
            )
        }

        log.debug("Getting token through continuation")
        return try await withCheckedThrowingContinuation { continuation in
            self.tokenContinuation = continuation

            log.info("Registering for remote notifications")
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }

            // Add timeout to prevent indefinite waiting
            Task {
                try await Task.sleep(nanoseconds: tokenRegistrationTimeoutSeconds * 1_000_000_000) // Timeout from constant
                if self.tokenContinuation != nil {
                    log.error("Timeout while waiting for push notification token")
                    self.tokenContinuation?.resume(throwing: NSError(
                        domain: "PushNotification",
                        code: 3,
                        userInfo: [NSLocalizedDescriptionKey: "Timeout while waiting for push notification token"]
                    ))
                    self.tokenContinuation = nil
                }
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
