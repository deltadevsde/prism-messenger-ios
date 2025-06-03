//
//  ProfilePictureGateway.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation
import SwiftUI

enum ProfilePictureGatewayError: Error {
    case downloadFailed
    case uploadFailed
}

@MainActor
protocol ProfilePictureGateway {

    /// Fetches profile picture data from the specified URL
    /// - Parameter url: The URL to fetch the profile picture from
    /// - Returns: The image data
    /// - Throws: ProfilePictureGatewayError if the fetch fails
    func fetchPicture(from url: String) async throws -> ProfilePicture?

    /// Uploads binary data to the specified URL with the given content type
    /// - Parameters:
    ///   - imageData: The binary data to upload
    ///   - url: The URL where the data should be uploaded
    /// - Throws: ProfilePictureGatewayError if the upload fails
    func uploadPicture(_ picture: ProfilePicture, to url: String) async throws
}
