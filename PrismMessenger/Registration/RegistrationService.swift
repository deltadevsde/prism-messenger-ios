//
//  RegistrationService.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation

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
    private let keyManager: KeyManager
    private let keyGateway: KeyGateway
    private let userService: UserService

    init(
        registrationGateway: RegistrationGateway,
        keyManager: KeyManager,
        keyGateway: KeyGateway,
        userService: UserService
    ) {
        self.registrationGateway = registrationGateway
        self.keyManager = keyManager
        self.keyGateway = keyGateway
        self.userService = userService
    }

    func checkUsernameAvailability(_ username: String) async -> Bool {
        await registrationGateway.checkUsernameAvailability(username)
    }

    func registerNewUser(username: String) async throws {
        // Step 1: Request registration and get challenge
        let challenge = try await requestRegistration(username: username)

        // Step 2: Sign challenge and finalize registration
        try await finalizeRegistration(username: username, challenge: challenge)

        // Step 3: Initialize key bundle and create user
        try await uploadNewKeybundleAndCreateUser(username: username)
    }

    private func requestRegistration(username: String) async throws -> RegistrationChallenge {
        guard
            let key = (try? await keyManager.fetchIdentityKeyFromKeychain())
                ?? (try? keyManager.createIdentityKeyPair())
        else {
            throw RegistrationError.unableToAcquireKey
        }

        do {
            return try await registrationGateway.requestRegistration(username: username, key: key)
        } catch RegistrationGatewayError.requestFailed(let errorCode) {
            throw RegistrationError.networkFailure(errorCode)
        }
    }

    private func finalizeRegistration(username: String, challenge: RegistrationChallenge)
        async throws
    {
        guard let key = try? await keyManager.fetchIdentityKeyFromKeychain() else {
            throw RegistrationError.unableToAcquireKey
        }

        guard !challenge.isEmpty else {
            throw RegistrationError.invalidChallenge
        }

        // Sign the challenge
        guard let signature = try? await keyManager.requestIdentitySignature(dataToSign: challenge)
        else {
            throw RegistrationError.unableToSignChallenge
        }

        do {
            try await registrationGateway
                .finalizeRegistration(username: username, key: key, signature: signature)
        } catch RegistrationGatewayError.requestFailed(let errorCode) {
            throw RegistrationError.networkFailure(errorCode)
        }
    }

    private func uploadNewKeybundleAndCreateUser(username: String) async throws {
        do {
            // Create all neccessary keys for the user's key bundle
            let idKey = try await keyManager.fetchIdentityKeyFromKeychain()
            let (signedPrekey, signedPrekeySignature) = try await keyManager.createSignedPrekey()
            let privatePrekeys = try await keyManager.createPrekeys(count: 10)
            
            // Create user and key bundle
            let user = User(signedPrekey: signedPrekey, username: username)
            try user.addPrekeys(keys: privatePrekeys)
            
            let prekeys = try user.getPublicPrekeys()
            
            let keyBundle = KeyBundle(
                identity_key: idKey,
                signed_prekey: signedPrekey.publicKey,
                signed_prekey_signature: signedPrekeySignature,
                prekeys: prekeys
            )
            
            // Upload the new key bundle to the server
            try await keyGateway.submitKeyBundle(for: username, keyBundle: keyBundle)
            
            // When the key bundle has been uploaded to the server, save the user locally
            try await userService.saveUser(user)
            await userService.selectAccount(username: username)
            
        } catch is KeyManagerError {
            throw RegistrationError.failedToCreateKey
        } catch KeyGatewayError.requestFailed(let errorCode) {
            throw RegistrationError.networkFailure(errorCode)
        }
    }
}
