//
//  MessengerServerRestClient.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation
import CryptoKit


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
            let response: RegistrationChallengeResponse = try await post(
                req, to: "/registration/request")
            return response.challenge
        } catch RestClientError.httpError(let httpStatusCode) {
            throw RegistrationGatewayError.requestFailed(httpStatusCode)
        }
    }

    func finalizeRegistration(
        username: String, key: P256.Signing.PublicKey, signature: P256.Signing.ECDSASignature
    ) async throws {
        let req = FinalizeRegistrationRequest(
            username: username,
            key: key.toCryptoPayload(),
            signature: signature.toCryptoPayload()
        )
        
        do {
            try await post(req, to: "/registration/finalize")
        } catch RestClientError.httpError(let httpStatusCode) {
            throw RegistrationGatewayError.requestFailed(httpStatusCode)
        }
    }

}
