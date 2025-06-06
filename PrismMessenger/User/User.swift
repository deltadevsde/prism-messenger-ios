//
//  User.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import CryptoKit
import Foundation
import SwiftData

struct UserPrekey: Codable {
    let idx: UInt64
    let key: CryptoPayload
}

@Model
final class User {

    @Attribute(.unique) var id: UUID


    var authPassword: String

    var apnsToken: Data?

    private var signedPrekeyData: CryptoPayload
    var signedPrekey: P256.KeyAgreement.PrivateKey {
        try! signedPrekeyData.toP256KAPrivateKey()
    }

    private var prekeys: [UserPrekey]
    private var prekeyCounter: UInt64 = 0

    init(
        id: UUID,
        signedPrekey: P256.KeyAgreement.PrivateKey,
        authPassword: String,
        apnsToken: Data? = nil
    ) {
        self.id = id
        self.signedPrekeyData = signedPrekey.toCryptoPayload()
        self.prekeys = []
        self.prekeyCounter = 0
        self.authPassword = authPassword
        self.apnsToken = apnsToken
    }

    func addPrekeys(keys: [P256.KeyAgreement.PrivateKey]) throws {
        for key in keys {
            prekeys.append(UserPrekey(idx: prekeyCounter, key: key.toCryptoPayload()))
            prekeyCounter += 1
        }
    }

    func getPrekey(keyIdx: UInt64) -> P256.KeyAgreement.PrivateKey? {
        return try! prekeys.first(where: { $0.idx == keyIdx })?.key.toP256KAPrivateKey()
    }

    /// Deletes the `Prekey` with the given index. To be called when a prekey is used by a conversation partner to initiate a conversation.
    func deletePrekey(keyIdx: UInt64) {
        prekeys.removeAll { $0.idx == keyIdx }
    }

    func getPublicPrekeys() -> [Prekey] {
        return
            prekeys
            .map {
                Prekey(
                    keyIdx: $0.idx,
                    key: try! $0.key.toP256KAPrivateKey().publicKey
                )
            }
    }
}
