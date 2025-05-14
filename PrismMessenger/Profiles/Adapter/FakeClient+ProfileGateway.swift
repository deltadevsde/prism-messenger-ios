//
//  FakeClient+ProfileGateway.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation

extension FakeClient: ProfileGateway {
    func fetchProfile(byAccountId accountId: UUID) async throws -> Profile? {
        store.firstInList(Profile.self) { $0.id == accountId }
    }

    func fetchProfile(byUsername username: String) async throws -> Profile? {
        store.firstInList(Profile.self) { $0.username == username }
    }
}
