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
struct DoubleRatchetHeader: Codable, Equatable {
    /// Sender’s ephemeral public key (raw representation)
    let ephemeralKey: Data
    /// Message counter within the current chain
    let messageNumber: UInt64
    /// Last message number of the previous chain (for skipped keys)
    let previousMessageNumber: UInt64
    /// Identifier of the one-time prekey used in the handshake (if used)
    let oneTimePrekeyID: UInt64?
}

/// The complete double ratchet message, including header and AEAD-encrypted ciphertext.
struct DoubleRatchetMessage: Codable {
    let header: DoubleRatchetHeader
    /// The ciphertext which includes the AES-GCM authentication tag (appended)
    let ciphertext: Data
    /// The nonce used for AES-GCM encryption
    let nonce: AES.GCM.Nonce
    
    enum CodingKeys: String, CodingKey {
        case header, ciphertext, nonceData
    }
    
    init(header: DoubleRatchetHeader, ciphertext: Data, nonce: AES.GCM.Nonce) {
        self.header = header
        self.ciphertext = ciphertext
        self.nonce = nonce
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        header = try container.decode(DoubleRatchetHeader.self, forKey: .header)
        ciphertext = try container.decode(Data.self, forKey: .ciphertext)
        
        let nonceData = try container.decode(Data.self, forKey: .nonceData)
        nonce = try AES.GCM.Nonce(data: nonceData)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(header, forKey: .header)
        try container.encode(ciphertext, forKey: .ciphertext)
        try container.encode(Data(nonce), forKey: .nonceData)
    }
}
