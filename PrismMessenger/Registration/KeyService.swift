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

///
class KeyService: ObservableObject {
    private let keyGateway: KeyGateway
    private let keyManager: KeyManager
    
    init(
        keyGateway: KeyGateway,
        keyManager: KeyManager
    ) {
        self.keyGateway = keyGateway
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
    
//    func submitKeyBundle(username: String, keyBundle: KeyBundle) async throws {
//        let req = UploadKeyBundleRequest(user_id: username, keybundle: keyBundle)
//        do {
//            try await restClient.post(req, to: "/keys/upload_bundle")
//        } catch RestClientError.httpError(let httpStatusCode) {
//            throw KeyServiceError.networkFailure(httpStatusCode)
//        }
//    }
//    
//    func getKeyBundle(username: String) async throws -> KeyBundle? {
//        do {
//            let keyBundle: KeyBundleResponse = try await restClient.fetch(from: "/keys/bundle/\(username)")
//            return keyBundle.key_bundle
//        } catch RestClientError.httpError(let httpStatusCode) {
//            if httpStatusCode == 404 {
//                throw KeyServiceError.userNotFound
//            }
//            throw KeyServiceError.networkFailure(httpStatusCode)
//        }
//    }
}

