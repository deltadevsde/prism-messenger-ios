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
    func submitKeyBundle(for username: String, keyBundle: KeyBundle) async throws {
        let req = UploadKeyBundleRequest(keyBundle: keyBundle)
        do {
            try await post(req, to: "/keys/bundle", accessLevel: .authenticated)
        } catch RestClientError.httpError(let httpStatusCode) {
            throw KeyGatewayError.requestFailed(httpStatusCode)
        }
    }

    func fetchKeyBundle(for username: String) async throws -> KeyBundle? {
        do {
            let keyBundle: KeyBundleResponse = try await fetch(
                from: "/keys/bundle/\(username)", accessLevel: .authenticated)
            return keyBundle.keyBundle
        } catch RestClientError.httpError(let httpStatusCode) {
            if httpStatusCode == 404 {
                throw KeyGatewayError.userNotFound
            }
            throw KeyGatewayError.requestFailed(httpStatusCode)
        }
    }
}
