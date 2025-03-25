//
//  Random.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation


 enum RandomError: Error {
    case countExceedsInt(UInt)
    case generationFailed(OSStatus)
}

public final class Random {

    public static func generateRandomBytes(_ count: UInt) throws -> Data {
        guard count > 0 else {
            return Data()
        }

        guard let countAsInt = Int(exactly: count) else {
            throw RandomError.countExceedsInt(count)
        }
        var randomBytes = Data(count: countAsInt)
        let err = randomBytes.withUnsafeMutableBytes { buffer in
            return SecRandomCopyBytes(kSecRandomDefault, countAsInt, buffer.baseAddress!)
        }
        guard err == errSecSuccess else {
            throw RandomError.generationFailed(err)
        }
        return randomBytes
    }
}
