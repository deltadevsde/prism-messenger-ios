//
//  UpdatePushTokenService.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation

private let log = Log.notifications

enum UpdatePushTokenError: Error {
    case noCurrentUser
    case networkFailure(Int)
    case tokenAcquisitionFailed
}

class UpdatePushTokenService: ObservableObject {
    private let userService: UserService
    private let userGateway: UserGateway
    private let pushNotificationCenter: PushNotificationCenter

    init(
        userService: UserService,
        userGateway: UserGateway,
        pushNotificationService: PushNotificationCenter
    ) {
        self.userService = userService
        self.userGateway = userGateway
        self.pushNotificationCenter = pushNotificationService
    }

    /// Updates the APNS token for the current user both locally and on the server
    @MainActor
    func updatePushToken() async throws {
        // Get the current user
        guard let currentUser = userService.currentUser else {
            log.warning("Push token update impossible, because there's no user")
            return
        }

        do {
            // Request a new APNS token
            let apnsToken = try await pushNotificationCenter.requestPushNotificationToken()
            let apnsTokenHex = apnsToken.map { String(format: "%02hhx", $0) }.joined()

            // Check if the token has changed
            if let existingToken = currentUser.apnsToken, existingToken == apnsToken {
                log.debug(
                    "Push token update not necessary (is still \(apnsTokenHex))"
                )
                return
            }

            // Update token on server
            try await updateTokenOnServer(apnsToken)

            // Update token locally
            currentUser.apnsToken = apnsToken
            try await userService.saveUser(currentUser)

            log.info("Successfully updated push token (is now \(apnsTokenHex))")
        } catch let error as NSError {
            log.error("Failed to update push token: \(error)")
            throw UpdatePushTokenError.tokenAcquisitionFailed
        }
    }

    /// Updates the APNS token on the server
    /// - Parameter apnsToken: The new APNS token
    private func updateTokenOnServer(_ apnsToken: Data) async throws {
        do {
            try await userGateway.updateApnsToken(apnsToken)
        } catch UserGatewayError.requestFailed(let statusCode) {
            log.error("Failed to update APNS token on server: Status code \(statusCode)")
            throw UpdatePushTokenError.networkFailure(statusCode)
        }
    }
}
