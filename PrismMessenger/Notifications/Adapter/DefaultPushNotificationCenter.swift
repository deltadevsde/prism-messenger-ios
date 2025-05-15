//
//  DefaultPushNotificationCenter.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import SwiftUI
import UserNotifications

private let log = Log.notifications

class DefaultPushNotificationCenter: PushNotificationCenter, PushNotificationDelegate {

    // Timeout in seconds for push notification token registration
    private let tokenRegistrationTimeoutSeconds: UInt64 = 30

    // Task used for timeout cancellation
    private var timeoutTask: Task<Void, Never>?

    // The continuation is thread-safe for resuming purposes
    private var tokenContinuation: CheckedContinuation<Data, Error>?

    deinit {
        cancelTimeoutTask()
    }

    // Get token using async/await
    func requestPushNotificationToken() async throws -> Data {
        // Cancel any existing token request first
        cancelExistingTokenRequest()

        log.debug("Requesting user auth for push notifications")
        let authGranted = try await UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound])

        guard authGranted else {
            log.error("No authorization for notifications")
            throw NSError(
                domain: "PushNotification",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Notification permission denied"]
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
            startTimeoutTask()
        }
    }

    private func cancelExistingTokenRequest() {
        cancelTimeoutTask()

        if let continuation = tokenContinuation {
            log.warning("Canceling existing token request")
            continuation.resume(
                throwing: NSError(
                    domain: "PushNotification",
                    code: 4,
                    userInfo: [NSLocalizedDescriptionKey: "Token request canceled by a new request"]
                )
            )
            tokenContinuation = nil
        }
    }

    private func startTimeoutTask() {
        timeoutTask = Task {
            do {
                try await Task.sleep(nanoseconds: tokenRegistrationTimeoutSeconds * 1_000_000_000)  // Timeout from constant
                handleTimeout()
            } catch {
                // Task was cancelled, do nothing
            }
        }
    }

    private func cancelTimeoutTask() {
        timeoutTask?.cancel()
        timeoutTask = nil
    }

    private func handleTimeout() {
        guard !Task.isCancelled else { return }

        if let continuation = tokenContinuation {
            log.error("Timeout while waiting for push notification token")
            continuation.resume(
                throwing: NSError(
                    domain: "PushNotification",
                    code: 3,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "Timeout while waiting for push notification token"
                    ]
                )
            )
            tokenContinuation = nil
        }
    }

    // Called by the AppDelegate when token is received
    func didRegisterForRemoteNotifications(withDeviceToken deviceToken: Data) {
        cancelTimeoutTask()

        if let continuation = tokenContinuation {
            continuation.resume(returning: deviceToken)
            tokenContinuation = nil
        } else {
            log.warning("Received push token but no continuation waiting")
        }
    }

    // Called by the AppDelegate when registration fails
    func didFailToRegisterForRemoteNotifications(withError error: Error) {
        cancelTimeoutTask()

        if let continuation = tokenContinuation {
            continuation.resume(throwing: error)
            tokenContinuation = nil
        } else {
            log.warning(
                "Received push token error but no continuation waiting: \(error.localizedDescription)"
            )
        }
    }
}
