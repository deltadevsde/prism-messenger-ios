//
//  UserData.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//
import SwiftData
import Foundation
import CryptoKit

@Model
final class UserData: Identifiable {
    @Attribute(.unique) var username: String
    
    /// P256 Signing Key in DER representation
    private var signedPrekey: CryptoPayload
    /// Prekeys saved internally as P256 Private keys in DER representation
    private var prekeys: [Prekey]
    private var prekeyCounter: UInt64 = 0
    
    init(signedPrekey: P256.Signing.PrivateKey, username: String) {
        let payload = CryptoPayload(algorithm: .secp256r1, bytes: signedPrekey.derRepresentation)
        self.signedPrekey = payload
        self.prekeys = []
        self.prekeyCounter = 0
        self.username = username
    }
    
    func addPrekeys(keys: [P256.Signing.PrivateKey]) throws {
        for key in keys {
            let payload = key.toCryptoPayload()
            prekeys.append(Prekey(key_idx: prekeyCounter, key: payload))
            prekeyCounter += 1
        }
    }
    
    func getPrekey(keyIdx: UInt64) throws -> P256.Signing.PrivateKey? {
        for prekey in prekeys {
            if prekey.key_idx == keyIdx {
                return try prekey.key.toP256PrivateKey()
            }
        }
        return nil
    }
    
    func getSignedPrekey() throws -> P256.Signing.PrivateKey? {
        return try signedPrekey.toP256PrivateKey()
    }
    
    /// Deletes the `Prekey` with the given index. To be called when a prekey is used by a conversation partner to initiate a conversation.
    func deletePrekey(keyIdx: UInt64) {
        prekeys.removeAll { $0.key_idx == keyIdx }
    }
    
    func getPublicPrekeys() throws -> [Prekey] {
        var publicPrekeys: [Prekey] = []
        for prekey in prekeys {
            let pubkey = try prekey.key.toP256PrivateKey().publicKey
            publicPrekeys.append(Prekey(key_idx: prekey.key_idx, key: pubkey.toCryptoPayload()))
        }
        return publicPrekeys
    }
}
