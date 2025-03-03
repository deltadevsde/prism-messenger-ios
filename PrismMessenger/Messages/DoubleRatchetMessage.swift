//
//  DoubleRatchetMessage.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation
import CryptoKit

// MARK: - Header & Message Types

/// Swift version of Rust `DoubleRatchetHeader`.
struct DoubleRatchetHeader: Codable {
    /// Sender’s ephemeral public key
    let ephemeral_key: P256.KeyAgreement.PublicKey
    /// Message counter within the current chain
    let message_number: UInt64
    /// Last message number of the previous chain (for skipped keys)
    let previous_message_number: UInt64
    /// Identifier of the one-time prekey used in the handshake (if used)
    let one_time_prekey_id: UInt64?
}

/// The complete double ratchet message, including header and AEAD-encrypted ciphertext.
struct DoubleRatchetMessage: Codable {
    let header: DoubleRatchetHeader
    /// The ciphertext which includes the AES-GCM authentication tag (appended)
    let ciphertext: Data
    /// The nonce used for AES-GCM encryption
    let nonce: AES.GCM.Nonce
    
    enum CodingKeys: String, CodingKey {
        case header, ciphertext, nonce
    }
    
    init(header: DoubleRatchetHeader, ciphertext: Data, nonce: AES.GCM.Nonce) {
        self.header = header
        self.ciphertext = ciphertext
        self.nonce = nonce
    }
    
    init(from decoder: Decoder) throws {
        print("DEBUG: Decoding DoubleRatchetMessage")
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        do {
            header = try container.decode(DoubleRatchetHeader.self, forKey: .header)
            print("DEBUG: Decoded header")
        } catch {
            print("DEBUG: Failed to decode header: \(error)")
            throw error
        }
        
        do {
            ciphertext = try container.decode(Data.self, forKey: .ciphertext)
            print("DEBUG: Decoded ciphertext")
        } catch {
            print("DEBUG: Failed to decode ciphertext: \(error)")
            throw error
        }
        
        do {
            let nonceData = try container.decode(Data.self, forKey: .nonce)
            print("DEBUG: Decoded nonceData: \(nonceData.count) bytes")
            nonce = try AES.GCM.Nonce(data: nonceData)
            print("DEBUG: Created AES.GCM.Nonce")
        } catch {
            print("DEBUG: Failed to decode nonce: \(error)")
            throw error
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(header, forKey: .header)
        try container.encode(ciphertext, forKey: .ciphertext)
        try container.encode(Data(nonce), forKey: .nonce)
    }
}
