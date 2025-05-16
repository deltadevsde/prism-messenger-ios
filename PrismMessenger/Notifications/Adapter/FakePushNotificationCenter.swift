//
//  FakePushNotificationCenter.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation

private let log = Log.notifications

/// Fake implementation of PushNotificationCenter for testing and previews
class FakePushNotificationCenter: PushNotificationCenter {
    /// Returns a randomly generated push notification token
    /// - Returns: Random Data as a push token
    func requestPushNotificationToken() async throws -> Data {
        log.trace("FakePushNotificationCenter returning random token")
        // Generate a random token of 32 bytes (typical push token size)
        return try Random.generateRandomBytes(32)
    }
}
