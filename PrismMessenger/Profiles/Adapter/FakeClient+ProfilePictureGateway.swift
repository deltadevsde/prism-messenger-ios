//
//  FakeClient+ProfilePictureGateway.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation
import SwiftUI

private struct StoredProfilePicture: Identifiable {
    var id: String { url }

    let url: String
    let data: Data
}

extension FakeClient: ProfilePictureGateway {

    private var profilePictureStore: InMemoryStore<StoredProfilePicture> {
        storeProvider.provideTypedStore()
    }

    func uploadPicture(_ imageData: Data, to url: String) async throws {
        profilePictureStore.save(StoredProfilePicture(url: url, data: imageData))
    }
}
