//
//  FakeClient+MessageGateway.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import CryptoKit
import Foundation

private let simulatedRegistrationChallenge = RegistrationChallenge(repeating: 0, count: 20)

extension FakeClient: RegistrationGateway {

    private var userStore: InMemoryStore<FakeUser> {
        storeProvider.provideTypedStore()
    }

    private var profileStore: InMemoryStore<Profile> {
        storeProvider.provideTypedStore()
    }

    func checkUsernameAvailability(_ username: String) async -> Bool {
        userStore.first { $0.username == username } == nil
    }

    func requestRegistration(username: String, key: P256.Signing.PublicKey) async throws
        -> RegistrationChallenge
    {
        // return zeroed data as challenge
        simulatedRegistrationChallenge
    }

    func finalizeRegistration(
        username: String, key: P256.Signing.PublicKey, signature: P256.Signing.ECDSASignature,
        authPassword: String, apnsToken: Data
    )
        async throws -> UUID
    {
        guard key.isValidSignature(signature, for: simulatedRegistrationChallenge) else {
            throw RegistrationError.signatureVerificationFailed
        }

        let registeredUser = FakeUser(
            username: username,
            authPassword: authPassword,
            apnsToken: apnsToken
        )
        userStore.save(registeredUser)

        let profile = Profile(
            accountId: registeredUser.id,
            username: registeredUser.username)
        profileStore.save(profile)

        return registeredUser.id
    }
}
