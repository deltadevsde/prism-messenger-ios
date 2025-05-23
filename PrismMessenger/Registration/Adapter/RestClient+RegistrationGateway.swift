//
//  MessengerServerRestClient.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import CryptoKit
import Foundation

struct RegistrationRequestData: Encodable {
    var username: String
    var key: CryptoPayload
}

struct RegistrationChallengeResponse: Decodable {
    var challenge: Data
}

struct FinalizeRegistrationRequest: Encodable {
    var username: String
    var key: CryptoPayload
    var signature: CryptoPayload
    var authPassword: String
    var apnsToken: Data
}

struct FinalizeRegistrationResponse: Decodable {
    var id: UUID
}

extension RestClient: RegistrationGateway {

    func checkUsernameAvailability(_ username: String) async -> Bool {
        let response = try? await head(from: "/accounts/account/\(username)")
        // If username not found, it is available
        return response?.statusCode == 404
    }

    func requestRegistration(username: String, key: P256.Signing.PublicKey) async throws
        -> RegistrationChallenge
    {
        let req = RegistrationRequestData(
            username: username,
            key: key.toCryptoPayload()
        )

        do {
            guard let response: RegistrationChallengeResponse = try await post(
                req, to: "/registration/request") else {
                throw RegistrationGatewayError.invalidResponse
            }
            return response.challenge
        } catch RestClientError.httpError(let httpStatusCode) {
            throw RegistrationGatewayError.requestFailed(httpStatusCode)
        }
    }

    func finalizeRegistration(
        username: String,
        key: P256.Signing.PublicKey,
        signature: P256.Signing.ECDSASignature,
        authPassword: String,
        apnsToken: Data
    ) async throws -> UUID {
        let req = FinalizeRegistrationRequest(
            username: username,
            key: key.toCryptoPayload(),
            signature: signature.toCryptoPayload(),
            authPassword: authPassword,
            apnsToken: apnsToken
        )

        do {
            guard let response: FinalizeRegistrationResponse = try await post(
                req,
                to: "/registration/finalize",
                accessLevel: .pub
            ) else {
                throw RegistrationGatewayError.invalidResponse
            }
            return response.id
        } catch RestClientError.httpError(let httpStatusCode) {
            throw RegistrationGatewayError.requestFailed(httpStatusCode)
        }
    }
}
