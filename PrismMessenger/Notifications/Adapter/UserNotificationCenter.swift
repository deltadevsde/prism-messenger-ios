//
//  UserNotificationCenter.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation
import UserNotifications

private let log = Log.notifications


/// Represents a UserNotificationCenter that can be UNUserNotificationCenter, or a fake for testing and previews
protocol UserNotificationCenter {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func add(_ request: UNNotificationRequest) async throws
}

/// Real UserNotificationCenter implementation wrapping UNUserNotificationCenter
class RealNotificationCenter: UserNotificationCenter {
    
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        return try await UNUserNotificationCenter.current().requestAuthorization(options: options)
    }
    
    func add(_ request: UNNotificationRequest) async throws {
        try await UNUserNotificationCenter.current().add(request)
    }
}

/// Fake UserNotificationCenter implementation for testing and previews
class FakeNotificationCenter: UserNotificationCenter {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        return true
    }
    
    func add(_ request: UNNotificationRequest) async throws {
        log.info("Requested notification: \(request)")
    }
}
