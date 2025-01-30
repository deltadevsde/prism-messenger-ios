//
//  KeyManager.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Security

enum KeyServiceError: Error {
    case fetchingFromKeychainFailed(OSStatus)
    case publicKeyDerivationFailed
}

struct KeyManager {
    private static let tag = "xyz.prism.messenger".data(using: .utf8)!
    
    static func fetchKeyFromKeyChain() async throws -> SecKey {
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: KeyManager.tag,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnRef as String: true,
        ]
        
        let (item, result) = await withCheckedContinuation { continuation in
            // Dispatch to other queue, because this is a blocking operation
            DispatchQueue.global(qos: .utility).async {
                var item: CFTypeRef?
                let result = SecItemCopyMatching(attributes as CFDictionary, &item)
                continuation.resume(returning: (item, result))
            }
        }
        guard result == errSecSuccess else {
            throw KeyServiceError.fetchingFromKeychainFailed(result)
        }
        
        let privateKey = item as! SecKey
        
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw KeyServiceError.publicKeyDerivationFailed
        }
        
        return publicKey
    }
    
    static func createKeyPair() throws -> SecKey {
        var error: Unmanaged<CFError>?
        
        guard
            let access = SecAccessControlCreateWithFlags(
                kCFAllocatorDefault,
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                [.privateKeyUsage, .biometryAny],
                &error)
        else {
            throw error!.takeRetainedValue() as Error
        }
        
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: KeyManager.tag,
                kSecAttrAccessControl as String: access,
            ],
        ]
        
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            throw error!.takeRetainedValue() as Error
        }
        
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw KeyServiceError.publicKeyDerivationFailed
        }
        
        return publicKey
    }

}

