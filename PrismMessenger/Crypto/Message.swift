//
//  Message.swift
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
struct DoubleRatchetMessage {
    let header: DoubleRatchetHeader
    /// The ciphertext which includes the AES-GCM authentication tag (appended)
    let ciphertext: Data
    /// The nonce used for AES-GCM encryption
    /// TODO(@distractedm1nd): Figure out serialization so we can make this struct `Codable`
    let nonce: AES.GCM.Nonce
}
