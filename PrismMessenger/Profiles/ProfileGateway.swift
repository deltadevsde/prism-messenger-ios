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

/// Actions that can be performed on a profile picture
enum ProfilePictureAction: String, Codable {
    /// Do not change the profile picture (default)
    case noChange = "NO_CHANGE"
    /// Remove the existing profile picture without setting a new one
    case clear = "CLEAR"
    /// Update the profile picture (will need to get an upload URL)
    case update = "UPDATE"
}

/// Request model for updating a user profile
struct UpdateProfileRequest: Codable {
    /// New display name (optional)
    var displayName: String?
    /// Action to perform on the profile picture
    var profilePictureAction: ProfilePictureAction = .noChange
}

/// Response model for profile picture upload URLs
struct ProfilePictureUploadResponse: Codable {
    /// Pre-signed URL for uploading to S3
    var uploadUrl: String
    /// URL where the picture will be accessible after upload
    var pictureUrl: String
    /// Expiration time for the upload URL in seconds
    var expiresIn: UInt64
}


@MainActor
protocol ProfileGateway {

    func fetchProfile(byAccountId accountId: UUID) async throws -> Profile?

    func fetchProfile(byUsername username: String) async throws -> Profile?

    func updateProfile(_ request: UpdateProfileRequest) async throws
        -> ProfilePictureUploadResponse?
}
