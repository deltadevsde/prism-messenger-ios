//
//  RegistrationGateway.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import CryptoKit
import Foundation

enum RegistrationGatewayError: Error {
    case requestFailed(Int)
}

protocol RegistrationGateway {
    /// Checks whether a username is available on the server
    func checkUsernameAvailability(_ username: String) async -> Bool

    /// Requests registration for a username/key on the server
    func requestRegistration(username: String, key: P256.Signing.PublicKey) async throws
        -> RegistrationChallenge

    /// Requests finalization of user registration on the server
    /// - Returns: UUID of the created user
    func finalizeRegistration(
        username: String, key: P256.Signing.PublicKey, signature: P256.Signing.ECDSASignature,
        authPassword: String, apnsToken: Data
    ) async throws -> UUID;
}
