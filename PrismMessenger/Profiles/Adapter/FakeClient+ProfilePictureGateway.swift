//
//  FakeClient+ProfilePictureGateway.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation
import SwiftUI

extension FakeClient: ProfilePictureGateway {

    private var profilePictureStore: InMemoryStore<ProfilePicture> {
        storeProvider.provideTypedStore()
    }

    func fetchPicture(from url: String) async throws -> ProfilePicture? {
        profilePictureStore.get(byId: url)
    }

    func uploadPicture(_ picture: ProfilePicture, to url: String) async throws {
        profilePictureStore.save(picture)
    }
}
