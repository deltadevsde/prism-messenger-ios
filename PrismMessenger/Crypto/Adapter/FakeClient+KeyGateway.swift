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
    }

    func fetchKeyBundle(for username: String) async throws -> KeyBundle? {
        try KeyBundle.random()
    }
}
