//
//  FakeClient+MessageGateway.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import CryptoKit
import Foundation

private let simulatedRegistrationChallenge = RegistrationChallenge(repeating: 0, count: 20)

private struct RegisteredUser {
    let username: String
    let key: P256.Signing.PublicKey
}

extension FakeClient: RegistrationGateway {

    func checkUsernameAvailability(_ username: String) async -> Bool {
        !store.getList(RegisteredUser.self).contains { $0.username == username }
    }

    func requestRegistration(username: String, key: P256.Signing.PublicKey) async throws
        -> RegistrationChallenge
    {
        // return zeroed data as challenge
        simulatedRegistrationChallenge
    }

    func finalizeRegistration(
        username: String, key: P256.Signing.PublicKey, signature: P256.Signing.ECDSASignature,
        authPassword: String, apnsToken: Data)
        async throws
    {
        guard key.isValidSignature(signature, for: simulatedRegistrationChallenge) else {
            throw RegistrationError.signatureVerificationFailed
        }

        let registeredUser = RegisteredUser(username: username, key: key)
        store.addToList(registeredUser)
    }
}
