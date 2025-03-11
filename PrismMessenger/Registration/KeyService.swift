//
//  KeyService.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation
import CryptoKit

enum KeyServiceError: Error {
    case unableToRetrieveKey
    case networkFailure(Int)
    case userNotFound
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

struct KeyBundleResponse: Codable {
    var key_bundle: KeyBundle?
    // TODO: Account and HashedMerkleProof
}

struct UploadKeyBundleRequest: Codable {
    var user_id: String
    var keybundle: KeyBundle
}

/// Concrete implementation of the KeyServiceProtocol
class KeyService: ObservableObject, KeyServiceProtocol {
    private let restClient: RestClient
    private let keyManager: KeyManager
    
    init(
        restClient: RestClient,
        keyManager: KeyManager
    ) {
        self.restClient = restClient
        self.keyManager = keyManager
    }
    
    /// Initializes a KeyBundle and User for a new user. Caller must ensure the new `User` is saved to the container .
    func initializeKeyBundle(username: String) async throws -> (KeyBundle, User) {
        let idKey = try await keyManager.fetchIdentityKeyFromKeychain()
        let (signedPrekey, signedPrekeySignature) = try await keyManager.createSignedPrekey()
        let privatePrekeys = try await keyManager.createPrekeys(count: 10)
        
        let user = User(signedPrekey: signedPrekey, username: username)
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
            throw KeyServiceError.networkFailure(httpStatusCode)
        }
    }
    
    /// Fetches a key bundle for a specific user from the server
    func getKeyBundle(username: String) async throws -> KeyBundle? {
        do {
            let keyBundle: KeyBundleResponse = try await restClient.fetch(from: "/keys/bundle/\(username)")
            return keyBundle.key_bundle
        } catch RestClientError.httpError(let httpStatusCode) {
            if httpStatusCode == 404 {
                throw KeyServiceError.userNotFound
            }
            throw KeyServiceError.networkFailure(httpStatusCode)
        }
    }
}

