//
//  FakeClient+ProfilePictureGateway.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation
import SwiftUI

private struct StoredProfilePicture {
    let data: Data
}

extension FakeClient: ProfilePictureGateway {

    func uploadPicture(_ imageData: Data, to url: String) async throws {
        let profilePicture = StoredProfilePicture(data: imageData)
        store.set(profilePicture, for: StoredProfilePicture.self)
    }
}
