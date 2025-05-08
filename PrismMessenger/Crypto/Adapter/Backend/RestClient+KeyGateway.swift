//
//  MessengerServerRestClient.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation

struct KeyBundleResponse: Codable {
    var keyBundle: KeyBundle?
    // TODO: Account and HashedMerkleProof
}

struct UploadKeyBundleRequest: Codable {
    var keyBundle: KeyBundle
}

extension RestClient: KeyGateway {
    func submitKeyBundle(keyBundle: KeyBundle) async throws {
        let req = UploadKeyBundleRequest(keyBundle: keyBundle)
        do {
            try await post(req, to: "/keys/bundle", accessLevel: .authenticated)
        } catch RestClientError.httpError(let httpStatusCode) {
            throw KeyGatewayError.requestFailed(httpStatusCode)
        }
    }

    func fetchKeyBundle(for accountId: UUID) async throws -> KeyBundle? {
        do {
            let keyBundle: KeyBundleResponse = try await fetch(
                from: "/keys/bundle/\(accountId)", accessLevel: .authenticated)
            return keyBundle.keyBundle
        } catch RestClientError.httpError(let httpStatusCode) {
            if httpStatusCode == 404 {
                throw KeyGatewayError.userNotFound
            }
            throw KeyGatewayError.requestFailed(httpStatusCode)
        }
    }
}
