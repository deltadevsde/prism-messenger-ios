//
//  SecKey+Base64.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Security
import Foundation

enum SecKeyBase64Error: Error {
    case conversionFailed
}

extension SecKey {
    public func toBase64() throws -> String {
        return try toBytes().base64EncodedString()
    }
    
    public static func fromBase64(_ base64String: String) throws -> SecKey {
        guard let bytes = Data(base64Encoded: base64String) else {
            throw SecKeyBase64Error.conversionFailed
        }
        
        return try SecKey.fromBytes(bytes)
    }
}
