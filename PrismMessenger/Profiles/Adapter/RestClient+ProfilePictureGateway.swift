//
//  RestClient+ProfilePictureGateway.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation
import SwiftUI

private let log = Log.profiles

extension RestClient: ProfilePictureGateway {

    func uploadPicture(_ imageData: Data, to url: String) async throws {
        do {
            try await putBinaryData(imageData, to: url, contentType: "image/jpeg")
        } catch {
            log.error("Error uploading to \(url): \(error)")
            throw ProfilePictureGatewayError.uploadFailed
        }
    }
}
