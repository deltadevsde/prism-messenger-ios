//
//  SecKey+Base64.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation
import Security

extension SecKey {
    public func toBytes() throws -> Data {
        var error: Unmanaged<CFError>?
        guard let data = SecKeyCopyExternalRepresentation(self, &error) as? Data else {
            throw error!.takeRetainedValue() as Error
        }

        return data
    }

    public static func fromBytes(_ bytes: Data) throws -> SecKey {
        let options: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeEC,
            kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
        ]
        var error: Unmanaged<CFError>?
        guard
            let key = SecKeyCreateWithData(
                bytes as CFData,
                options as CFDictionary,
                &error)
        else {
            throw error!.takeRetainedValue() as Error
        }

        return key
    }
}
