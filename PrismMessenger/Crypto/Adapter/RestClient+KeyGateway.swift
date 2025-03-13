//
//  MessengerServerRestClient.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation

struct KeyBundleResponse: Codable {
    var key_bundle: KeyBundle?
    // TODO: Account and HashedMerkleProof
}

struct UploadKeyBundleRequest: Codable {
    var user_id: String
    var keybundle: KeyBundle
}

extension RestClient: KeyGateway {
    func submitKeyBundle(for username: String, keyBundle: KeyBundle) async throws {
        let req = UploadKeyBundleRequest(user_id: username, keybundle: keyBundle)
        do {
            try await post(req, to: "/keys/upload_bundle")
        } catch RestClientError.httpError(let httpStatusCode) {
            throw KeyGatewayError.requestFailed(httpStatusCode)
        }
    }

    func fetchKeyBundle(for username: String) async throws -> KeyBundle? {
        do {
            let keyBundle: KeyBundleResponse = try await fetch(
                from: "/keys/bundle/\(username)")
            return keyBundle.key_bundle
        } catch RestClientError.httpError(let httpStatusCode) {
            if httpStatusCode == 404 {
                throw KeyGatewayError.userNotFound
            }
            throw KeyGatewayError.requestFailed(httpStatusCode)
        }
    }
}
