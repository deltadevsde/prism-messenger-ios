//
//  ProfilePictureGateway.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation
import SwiftUI

enum ProfilePictureGatewayError: Error {
    case uploadFailed
}

@MainActor
protocol ProfilePictureGateway {

    /// Uploads binary data to the specified URL with the given content type
    /// - Parameters:
    ///   - imageData: The binary data to upload
    ///   - url: The URL where the data should be uploaded
    /// - Throws: ProfilePictureGatewayError if the upload fails
    func uploadPicture(_ imageData: Data, to url: String) async throws
}
