//
//  FakeClient+MessageGateway.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation

private struct StoredKeyBundle {
    let username: String
    let keyBundle: KeyBundle
}

extension FakeClient: KeyGateway {
    func submitKeyBundle(for username: String, keyBundle: KeyBundle) async throws {
        store.addToList(StoredKeyBundle(username: username, keyBundle: keyBundle))
    }

    func fetchKeyBundle(for username: String) async throws -> KeyBundle? {
        store.getList(StoredKeyBundle.self).first { $0.username == username }?.keyBundle
    }
}
