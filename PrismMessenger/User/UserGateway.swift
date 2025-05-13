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
    /// - Throws: UserGatewayError if the request fails
    func updateApnsToken(_ apnsToken: Data) async throws
}