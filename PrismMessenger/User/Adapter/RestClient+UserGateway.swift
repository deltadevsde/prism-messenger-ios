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

extension RestClient: UserGateway {
    func updateApnsToken(_ apnsToken: Data) async throws {
        let request = UpdateApnsTokenRequest(token: apnsToken)

        do {
            try await put(request, to: "/accounts/apns", accessLevel: .authenticated)
        } catch RestClientError.httpError(let statusCode) {
            throw UserGatewayError.requestFailed(statusCode)
        }
    }
}
