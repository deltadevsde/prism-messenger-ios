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
    case unknown
}

struct RegisterRequest: Encodable {
    var username: String
    var key: CryptoPayload
}

struct CreateAccountResponse: Decodable {

}

class RegistrationService: ObservableObject {

    private let restClient: RestClient

    init(restClient: RestClient) {
        self.restClient = restClient
    }

    func checkUsernameAvailability(_ username: String) async -> Bool {
        let response = try? await restClient.head(from: "/accounts/account/\(username)")
        // If username not found, it is available
        return response?.statusCode == 404
    }

    func register(username: String) async throws {
        guard
            let key = (try? await KeyManager.fetchKeyFromKeyChain())
                ?? (try? KeyManager.createKeyPair())
        else {
            throw RegistrationError.unableToAcquireKey
        }

        let req = RegisterRequest(
            username: username, key: CryptoPayload(algorithm: .secp256r1, bytes: try key.toBytes()))
        do {
            try await restClient.post(req, to: "/register")
        } catch RestClientError.httpError(let httpStatusCode) {
            throw RegistrationError.networkFailure(httpStatusCode)
        }
    }

}
