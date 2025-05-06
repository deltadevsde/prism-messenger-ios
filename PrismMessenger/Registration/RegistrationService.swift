//
//  RegistrationService.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation

private let log = Log.registration

enum RegistrationError: Error {
    case networkFailure(Int)
    case unableToAcquireKey
    case failedToCreateKey
    case unableToSignChallenge
    case invalidChallenge
    case signatureVerificationFailed
    case unknown
}

/// Concrete implementation of the RegistrationServiceProtocol
class RegistrationService: ObservableObject {

    private let registrationGateway: RegistrationGateway
    private let tee: TrustedExecutionEnvironment
    private let keyGateway: KeyGateway
    private let pushNotificationService: PushNotificationService
    private let userService: UserService

    init(
        registrationGateway: RegistrationGateway,
        tee: TrustedExecutionEnvironment,
        keyGateway: KeyGateway,
        pushNotificationService: PushNotificationService,
        userService: UserService
    ) {
        self.registrationGateway = registrationGateway
        self.tee = tee
        self.keyGateway = keyGateway
        self.pushNotificationService = pushNotificationService
        self.userService = userService
    }

    func checkUsernameAvailability(_ username: String) async -> Bool {
        await registrationGateway.checkUsernameAvailability(username)
    }

    func registerNewUser(username: String) async throws {
        // Step 1: Request registration and get challenge
        let challenge = try await requestRegistration(username: username)

        let authPassword = try generateServerAuthPassword()
        let apnsToken = try await pushNotificationService.requestPushNotificationToken()

        // Step 2: Sign challenge and finalize registration
        let userId = try await finalizeRegistration(
            username: username,
            authPassword: authPassword,
            apnsToken: apnsToken,
            challenge: challenge
        )

        // Step 3: Initialize key bundle and create user
        try await uploadNewKeybundleAndCreateUser(
            id: userId,
            username: username,
            authPassword: authPassword,
            apnsToken: apnsToken
        )
    }

    private func requestRegistration(username: String) async throws -> RegistrationChallenge {
        guard let key = try? tee.fetchOrCreateIdentityKey() else {
            throw RegistrationError.unableToAcquireKey
        }

        do {
            return try await registrationGateway.requestRegistration(username: username, key: key)
        } catch RegistrationGatewayError.requestFailed(let errorCode) {
            throw RegistrationError.networkFailure(errorCode)
        }
    }

    private func finalizeRegistration(
        username: String,
        authPassword: String,
        apnsToken: Data,
        challenge: RegistrationChallenge
    )
        async throws -> UUID
    {
        guard let key = try? tee.fetchOrCreateIdentityKey() else {
            throw RegistrationError.unableToAcquireKey
        }

        guard !challenge.isEmpty else {
            throw RegistrationError.invalidChallenge
        }

        // Sign the challenge
        guard let signature = try? tee.requestIdentitySignature(dataToSign: challenge)
        else {
            throw RegistrationError.unableToSignChallenge
        }

        do {
            return try await registrationGateway.finalizeRegistration(
                username: username,
                key: key,
                signature: signature,
                authPassword: authPassword,
                apnsToken: apnsToken
            )
        } catch RegistrationGatewayError.requestFailed(let errorCode) {
            throw RegistrationError.networkFailure(errorCode)
        }
    }

    private func uploadNewKeybundleAndCreateUser(
        id: UUID,
        username: String,
        authPassword: String,
        apnsToken: Data
    )
        async throws
    {
        do {
            // Create all neccessary keys for the user's key bundle
            let userKeys = try tee.createUserKeys()

            // Create user and key bundle
            let user = User(
                id: id,
                signedPrekey: userKeys.signedPrekey,
                username: username,
                authPassword: authPassword,
                apnsToken: apnsToken
            )
            try user.addPrekeys(keys: userKeys.prekeys)

            // When the user has been created, save it and set is as active user
            try await userService.saveUser(user)
            await userService.selectAccount(username: username)

            // Upload the created key bundle to the server
            let prekeys = user.getPublicPrekeys()

            let keyBundle = KeyBundle(
                identityKey: userKeys.identityKey,
                signedPrekey: userKeys.signedPrekey.publicKey,
                signedPrekeySignature: userKeys.signedPrekeySignature,
                prekeys: prekeys
            )

            try await keyGateway.submitKeyBundle(for: username, keyBundle: keyBundle)
        } catch is TeeError {
            throw RegistrationError.failedToCreateKey
        } catch KeyGatewayError.requestFailed(let errorCode) {
            throw RegistrationError.networkFailure(errorCode)
        }
    }

    private func generateServerAuthPassword() throws -> String {
        return try Random.generateRandomBytes(16).base64EncodedString()
    }
}
