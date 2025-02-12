//
//  KeyService.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation
import CryptoKit

// TODO(@distractedm1nd): KeyServiceError already exists, fix naming
enum KeyError: Error {
    case unableToRetrieveKey
    case networkFailure(Int)
}

struct Prekey: Codable {
    var key_idx: UInt64
    var key: CryptoPayload
}

struct KeyBundle: Codable {
    var identity_key: CryptoPayload
    var signed_prekey: CryptoPayload
    var signed_prekey_signature: CryptoPayload
    var prekeys: [Prekey]
}

struct UploadKeyBundleRequest: Codable {
    var user_id: String
    var keybundle: KeyBundle
}

class KeyService: ObservableObject {
    private let restClient: RestClient
    private let keyManager: KeyManager
    
    init(
        restClient: RestClient,
        keyManager: KeyManager
    ) {
        self.restClient = restClient
        self.keyManager = keyManager
    }
    
    /// Initializes a KeyBundle and UserData for a new user. Caller must ensure the new `UserData` is saved to the container .
    func initializeKeyBundle(username: String) async throws -> (KeyBundle, UserData) {
        let idKey = try await keyManager.fetchIdentityKeyFromKeychain()
        let (signedPrekey, signedPrekeySignature) = try await keyManager.createSignedPrekey()
        let privatePrekeys = try await keyManager.createPrekeys(count: 10)
        
        let user = UserData(signedPrekey: signedPrekey, username: username)
        try user.addPrekeys(keys: privatePrekeys)
        let prekeys = try user.getPublicPrekeys()
        
        return (KeyBundle(
            identity_key: idKey.toCryptoPayload(),
            signed_prekey: signedPrekey.publicKey.toCryptoPayload(),
            signed_prekey_signature: signedPrekeySignature.toCryptoPayload(),
            prekeys: prekeys
        ), user)
    }
    
    /// Submits a user's key bundle to the server
    func submitKeyBundle(username: String, keyBundle: KeyBundle) async throws {
        let req = UploadKeyBundleRequest(user_id: username, keybundle: keyBundle)
        do {
            try await restClient.post(req, to: "/keys/upload_bundle")
        } catch RestClientError.httpError(let httpStatusCode) {
            throw KeyError.networkFailure(httpStatusCode)
        }
    }
}
