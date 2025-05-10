//
//  RestClient+UserGateway.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation

struct UpdateApnsTokenRequest: Encodable {
    var token: Data
}

struct UserInfoResponse: Decodable {
    var id: UUID
}

extension RestClient: UserGateway {

    func updateApnsToken(_ apnsToken: Data) async throws {
        let request = UpdateApnsTokenRequest(token: apnsToken)

        do {
            try await put(request, to: "/accounts/apns", accessLevel: .authenticated)
        } catch RestClientError.httpError(let statusCode) {
            throw UserGatewayError.requestFailed(statusCode)
        }
    }

    func fetchAccountId(for username: String) async throws -> UUID? {
        do {
            let response: UserInfoResponse = try await fetch(
                from: "/accounts/account/\(username)", accessLevel: .authenticated)
            return response.id
        } catch RestClientError.httpError(let statusCode) where statusCode == 404 {
            return nil
        } catch RestClientError.httpError(let statusCode) {
            throw UserGatewayError.requestFailed(statusCode)
        }
    }
}
