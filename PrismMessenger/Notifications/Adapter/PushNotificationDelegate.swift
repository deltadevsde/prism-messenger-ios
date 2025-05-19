//
//  PushNotificationDelegate.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation

/// Describes how push notifications can be delegated to adapters
protocol PushNotificationDelegate: AnyObject {
    /// Called when the device successfully registers for remote notifications
    /// - Parameter withDeviceToken: The device token received from Apple Push Notification service
    func didRegisterForRemoteNotifications(withDeviceToken: Data)

    /// Called when the device fails to register for remote notifications
    /// - Parameter withError: The error that occurred during registration
    func didFailToRegisterForRemoteNotifications(withError: Error)
}
