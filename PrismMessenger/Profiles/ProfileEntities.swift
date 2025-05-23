//
//  ProfileEntities.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation
import SwiftData

@Model
final class Profile: Identifiable {
    var id: UUID { accountId }
    @Attribute(.unique) var accountId: UUID
    @Attribute(.unique) var username: String
    var displayName: String?
    var picture: String?

    init(
        accountId: UUID,
        username: String,
        displayName: String? = nil,
        picture: String? = nil
    ) {
        self.accountId = accountId
        self.username = username
        self.displayName = displayName
        self.picture = picture
    }
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
