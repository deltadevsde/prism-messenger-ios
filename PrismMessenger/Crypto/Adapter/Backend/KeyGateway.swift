//
//  KeyGateway.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

enum KeyGatewayError: Error {
    case userNotFound
    case requestFailed(Int)
}


protocol KeyGateway {
    /// Submits a user's key bundle to the server
    func submitKeyBundle(for username: String, keyBundle: KeyBundle) async throws;
    
    /// Fetches a key bundle for a specific user from the server
    func fetchKeyBundle(for username: String) async throws -> KeyBundle?;
}
