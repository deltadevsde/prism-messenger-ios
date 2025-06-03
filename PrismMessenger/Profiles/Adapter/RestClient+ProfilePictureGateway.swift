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
    func fetchPicture(from url: String) async throws -> ProfilePicture? {
        do {
            let data = try await getBinaryData(from: url, contentType: "image/jpeg")
            return ProfilePicture(path: url, data: data)
        } catch {
            log.error("Error uploading to \(url): \(error)")
            throw ProfilePictureGatewayError.downloadFailed
        }
    }

    func uploadPicture(_ picture: ProfilePicture, to url: String) async throws {
        do {
            try await putBinaryData(picture.data, to: url, contentType: "image/jpeg")
        } catch {
            log.error("Error uploading to \(url): \(error)")
            throw ProfilePictureGatewayError.uploadFailed
        }
    }
}
