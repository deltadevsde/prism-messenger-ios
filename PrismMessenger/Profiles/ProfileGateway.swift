//
//  ProfileGateway.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation

enum ProfileGatewayError: Error {
    case requestFailed(Int)
}

protocol ProfileGateway {

    func fetchProfile(byAccountId accountId: UUID) async throws -> Profile?

    func fetchProfile(byUsername username: String) async throws -> Profile?
}
