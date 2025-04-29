//
//  UserNotificationCenter.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation
import UserNotifications

private let log = Log.notifications


enum UserNotificationCategory: String {
    case message = "message"
}

enum UserNotificationSound {
    case `default`
}

extension UserNotificationSound {
    var unNotificationSound: UNNotificationSound {
        switch self {
        case .default:
            return .default
        }
    }
}

struct UserNotificationRequest {
    let identifier: String
    let title: String
    let category: UserNotificationCategory
    let sound: UserNotificationSound
    let content: String
}

extension UserNotificationRequest: CustomStringConvertible {
    var description: String {
        "[\(category)] \(title) (\(identifier))"
    }
}

struct UserNotificationResponse {
    let identifier: String
    let category: UserNotificationCategory
    let actionIdentifier: String?
}

extension UserNotificationResponse: CustomStringConvertible {
    var description: String {
        if let action = actionIdentifier {
            return "[\(category)] \(identifier) (\(action))"
        }
        return "[\(category)] \(identifier)"
    }
}

protocol UserNotificationResponseHandler {

    func handleNotificationResponse(_ response: UserNotificationResponse) async
}

/// Can be used for sending and receiving user notifications
protocol UserNotificationCenter {

    func requestAuthorization() async throws -> Bool

    func post(_ request: UserNotificationRequest) async throws

    func setResponseHandler(
        _ handler: UserNotificationResponseHandler,
        for category: UserNotificationCategory
    )
}
