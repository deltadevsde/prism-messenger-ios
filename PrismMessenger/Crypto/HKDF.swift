//
//  HKDF.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation
import CryptoKit

// MARK: - Simple HKDF (RFC 5869) Implementation Using SHA256

/// Returns the pseudorandom key (PRK) by performing HKDF-Extract.
/// If no salt is provided (i.e. an empty Data), a salt of zeros is used.
public func hkdfExtract(salt: Data, inputKeyingMaterial ikm: Data) -> Data {
    // If salt is empty, use a salt of HashLen (32 bytes for SHA256) zeros.
    let effectiveSalt = salt.isEmpty ? Data(repeating: 0, count: Int(SHA256.byteCount)) : salt
    let saltKey = SymmetricKey(data: effectiveSalt)
    let prk = HMAC<SHA256>.authenticationCode(for: ikm, using: saltKey)
    return Data(prk)
}

/// Expands the pseudorandom key (PRK) into output keying material (OKM).
public func hkdfExpand(prk: Data, info: Data, outputLength: Int) -> Data {
    var okm = Data()
    var previousBlock = Data()
    var counter: UInt8 = 1

    while okm.count < outputLength {
        var data = Data()
        // T(n) = HMAC(PRK, T(n-1) || info || counter)
        data.append(previousBlock)
        data.append(info)
        data.append(counter)
        
        let prkKey = SymmetricKey(data: prk)
        let block = HMAC<SHA256>.authenticationCode(for: data, using: prkKey)
        previousBlock = Data(block)
        okm.append(previousBlock)
        counter += 1
    }
    
    return okm.prefix(outputLength)
}

/// HKDF that takes input keying material, salt, and info and returns derived key material.
public func hkdf(inputKeyingMaterial ikm: Data, salt: Data, info: Data, outputLength: Int) -> Data {
    let prk = hkdfExtract(salt: salt, inputKeyingMaterial: ikm)
    let okm = hkdfExpand(prk: prk, info: info, outputLength: outputLength)
    return okm
}
