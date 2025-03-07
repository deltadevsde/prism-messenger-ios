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
    case unableToSignChallenge
    case invalidChallenge
    case unknown
}

struct RegistrationRequestData: Encodable {
    var username: String
    var key: CryptoPayload
}

struct RegistrationChallenge: Decodable {
    var challenge: Data
}

struct FinalizeRegistrationRequest: Encodable {
    var username: String
    var key: CryptoPayload
    var signature: CryptoPayload
}

/// Concrete implementation of the RegistrationServiceProtocol
class RegistrationService: ObservableObject, RegistrationServiceProtocol {

    private let restClient: RestClient

    private let keyManager: KeyManager

    init(
        restClient: RestClient,
        keyManager: KeyManager
    ) {
        self.restClient = restClient
        self.keyManager = keyManager
    }

    func checkUsernameAvailability(_ username: String) async -> Bool {
        let response = try? await restClient.head(from: "/accounts/account/\(username)")
        // If username not found, it is available
        return response?.statusCode == 404
    }
    
    func requestRegistration(username: String) async throws -> RegistrationChallenge {
        guard
            let key = (try? await keyManager.fetchIdentityKeyFromKeychain())
                ?? (try? keyManager.createIdentityKeyPair())
        else {
            throw RegistrationError.unableToAcquireKey
        }

        let req = RegistrationRequestData(
            username: username,
            key: key.toCryptoPayload()
        )
        
        do {
            return try await restClient.post(req, to: "/registration/request")
        } catch RestClientError.httpError(let httpStatusCode) {
            throw RegistrationError.networkFailure(httpStatusCode)
        }
    }
    
    func finalizeRegistration(username: String, challenge: RegistrationChallenge) async throws {
        guard let key = try? await keyManager.fetchIdentityKeyFromKeychain() else {
            throw RegistrationError.unableToAcquireKey
        }
        
        guard !challenge.challenge.isEmpty else {
            throw RegistrationError.invalidChallenge
        }
        
        // Sign the challenge
        guard let signature = try? await keyManager.requestIdentitySignature(dataToSign: challenge.challenge) else {
            throw RegistrationError.unableToSignChallenge
        }
        
        let req = FinalizeRegistrationRequest(
            username: username,
            key: key.toCryptoPayload(),
            signature: signature.toCryptoPayload()
        )
        
        do {
            try await restClient.post(req, to: "/registration/finalize")
        } catch RestClientError.httpError(let httpStatusCode) {
            throw RegistrationError.networkFailure(httpStatusCode)
        }
    }
    
    func register(username: String) async throws {
        // Legacy method that performs full registration flow
        let challenge = try await requestRegistration(username: username)
        try await finalizeRegistration(username: username, challenge: challenge)
    }
}

