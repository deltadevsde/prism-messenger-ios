//
//  PushNotificationCenter.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation

/// Protocol for push notification token handling
protocol PushNotificationCenter {
    /// Request push notification token from the device
    /// - Returns: Push notification token as Data
    /// - Throws: Error if token retrieval fails
    func requestPushNotificationToken() async throws -> Data
}
