//
//  RestClient+PresenceGateway.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation

enum PresenceGatewayError: Error {
    case userNotFound
    case requestFailed(Int)
}

private struct PresenceResponse: Codable {
    let status: PresenceStatus
}

extension RestClient: PresenceFetchGateway {

    func fetchPresenceStatus(for accountId: UUID) async throws -> PresenceStatus {
        do {
            let response: PresenceResponse = try await fetch(
                from: "/presence/\(accountId.uuidString)",
                accessLevel: .authenticated
            )

            return response.status
        } catch RestClientError.httpError(let httpStatusCode) {
            if httpStatusCode == 404 {
                throw PresenceGatewayError.userNotFound
            }
            throw PresenceGatewayError.requestFailed(httpStatusCode)
        }
    }
}
