//
//  RestClient+ProfileGateway.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation

struct ProfileResponse: Decodable {
    /// UUID of the associated account
    var accountId: UUID
    /// Username of the associated account
    var username: String
}

extension RestClient: ProfileGateway {
    func fetchProfile(byAccountId accountId: UUID) async throws -> Profile? {
        do {
            let response: ProfileResponse = try await fetch(
                from: "/profile/\(accountId.uuidString)", accessLevel: .authenticated)

            return Profile(accountId: response.accountId, username: response.username)
        } catch RestClientError.httpError(let statusCode) {
            if statusCode == 404 {
                return nil
            }
            throw UserGatewayError.requestFailed(statusCode)
        }
    }

    func fetchProfile(byUsername username: String) async throws -> Profile? {
        do {
            let response: ProfileResponse = try await fetch(
                from: "/profile/by-username/\(username)", accessLevel: .authenticated)

            return Profile(accountId: response.accountId, username: response.username)
        } catch RestClientError.httpError(let statusCode) {
            if statusCode == 404 {
                return nil
            }
            throw UserGatewayError.requestFailed(statusCode)
        }
    }
}
