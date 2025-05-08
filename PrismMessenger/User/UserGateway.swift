//
//  UserGateway.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation

enum UserGatewayError: Error {
    case requestFailed(Int)
}

protocol UserGateway {
    /// Updates the user's APNS push token on the server
    /// - Parameter apnsToken: The APNS token to update
    func updateApnsToken(_ apnsToken: Data) async throws

    /// Fetches the user ID associated with a given username
    /// - Parameter username: The username to look up
    /// - Returns: The UUID of the user, or nil if no ID found for the given username
    /// - Throws: UserGatewayError if the request fails
    func fetchAccountId(for username: String) async throws -> UUID?
}
