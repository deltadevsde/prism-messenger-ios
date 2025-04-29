//
//  FakeUserNotificationCenter.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

private let log = Log.notifications


/// Fake UserNotificationCenter implementation for testing and previews
class FakeUserNotificationCenter: UserNotificationCenter {

    private var handlers: [UserNotificationCategory: UserNotificationResponseHandler] = [:]

    func requestAuthorization() async throws -> Bool {
        return true
    }

    func post(_ request: UserNotificationRequest) async throws {
        log.info("Requested notification \(request.title) (\(request.identifier))")

        // simulate direct user response
        let response = UserNotificationResponse(
            identifier: request.identifier,
            category: request.category,
            actionIdentifier: nil
        )
        await handlers[request.category]?.handleNotificationResponse(response)
    }

    func setResponseHandler(
        _ handler: any UserNotificationResponseHandler,
        for category: UserNotificationCategory
    ) {
        handlers[category] = handler
    }
}
