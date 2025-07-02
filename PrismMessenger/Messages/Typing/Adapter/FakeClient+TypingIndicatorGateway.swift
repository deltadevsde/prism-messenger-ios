//
//  FakeClient+TypingGateway.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation

extension FakeClient: TypingGateway {

    func sendTypingStatus(for accountId: UUID, isTyping: Bool) async throws {
        // In a real implementation, this would send the typing status to the server
        // For testing, we can just log or store the call for verification
        print("FakeClient: Sending typing status for \(accountId): \(isTyping)")
    }

    func handleTypingChanges(_ callback: @escaping (UUID, Bool) async throws -> Void) {
        // In a real implementation, this would set up a listener for incoming typing updates
        // For testing, we can store the callback to be called manually in tests
        print("FakeClient: Setting up typing handler")

        // Note: In a real fake implementation for integration tests, you might want to
        // store this callback and allow tests to trigger it manually to simulate
        // receiving typing updates from other users
    }
}
