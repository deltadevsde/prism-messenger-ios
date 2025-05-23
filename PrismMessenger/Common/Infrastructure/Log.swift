//
//  Logger.swift
//  PrismMessenger
//
//  Created by Jonas Pusch on 24.03.25.
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation
import os

public enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "xyz.prism.PrismMessenger"

    public static func forCategory(_ category: String) -> Logger {
        return Logger(subsystem: subsystem, category: category)
    }

    // Convenience loggers for common categories
    public static let common = forCategory("common")
    public static let crypto = forCategory("crypto")
    public static let messages = forCategory("messages")
    public static let profiles = forCategory("profiles")
    public static let registration = forCategory("registration")
    public static let notifications = forCategory("notifications")
    public static let user = forCategory("user")
}
