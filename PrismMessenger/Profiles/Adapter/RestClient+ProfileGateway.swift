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

    var displayName: String?

    var picture: String?
}

extension ProfileResponse {
    func toProfile() -> Profile {
        return Profile(
            accountId: self.accountId,
            username: self.username,
            displayName: self.displayName,
            picture: self.picture
        )
    }
}

extension RestClient: ProfileGateway {

    func fetchProfile(byAccountId accountId: UUID) async throws -> Profile? {
        do {
            let response: ProfileResponse = try await fetch(
                from: "/profile/\(accountId.uuidString)",
                accessLevel: .authenticated
            )

            return response.toProfile()
        } catch RestClientError.httpError(let statusCode) {
            if statusCode == 404 {
                return nil
            }
            throw ProfileGatewayError.requestFailed(statusCode)
        }
    }

    func fetchProfile(byUsername username: String) async throws -> Profile? {
        do {
            let response: ProfileResponse = try await fetch(
                from: "/profile/by-username/\(username)",
                accessLevel: .authenticated
            )

            return response.toProfile()
        } catch RestClientError.httpError(let statusCode) {
            if statusCode == 404 {
                return nil
            }
            throw ProfileGatewayError.requestFailed(statusCode)
        }
    }

    func updateProfile(_ request: UpdateProfileRequest) async throws
        -> ProfilePictureUploadResponse?
    {
        do {
            return try await patch(
                request,
                to: "/profile",
                accessLevel: .authenticated
            )
        } catch RestClientError.httpError(let statusCode) {
            throw ProfileGatewayError.requestFailed(statusCode)
        }
    }
}
