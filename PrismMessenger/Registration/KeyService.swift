//
//  KeyService.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation
import CryptoKit

// TODO(@distractedm1nd): KeyServiceError already exists, fix naming
// KeyError is defined in BackendGateway.swift
enum KeyServiceError: Error {
    case unableToRetrieveKey
}

struct PrivatePrekey: Codable {
    var key_idx: UInt64
    var key: CryptoPayload
}

struct Prekey: Codable {
    var key_idx: UInt64
    var key: P256.Signing.PublicKey
    
    func fromPrivatePrekey(_ prekey: PrivatePrekey) throws -> Prekey {
        try Prekey(key_idx: prekey.key_idx, key: prekey.key.toP256PrivateKey().publicKey)
    }
}

struct KeyBundle: Codable {
    var identity_key: P256.Signing.PublicKey
    var signed_prekey: P256.Signing.PublicKey
    var signed_prekey_signature: P256.Signing.ECDSASignature
    var prekeys: [Prekey]
}

// KeyBundleResponse and UploadKeyBundleRequest are defined in BackendGateway.swift

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
            identity_key: idKey,
            signed_prekey: signedPrekey.publicKey,
            signed_prekey_signature: signedPrekeySignature,
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
    
    /// Fetches a key bundle for a specific user from the server
    func getKeyBundle(username: String) async throws -> KeyBundle {
        do {
            let response: KeyBundleResponse = try await restClient.fetch(from: "/keys/bundle/\(username)")
            guard let keyBundle = response.key_bundle else {
                throw KeyError.userNotFound
            }
            return keyBundle
        } catch RestClientError.httpError(let httpStatusCode) {
            if httpStatusCode == 404 {
                throw KeyError.userNotFound
            }
            throw KeyError.networkFailure(httpStatusCode)
        }
    }
}
