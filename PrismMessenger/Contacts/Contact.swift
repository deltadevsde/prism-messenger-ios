//
//  Contact.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation
import SwiftData

@Model
final class Contact {

    @Attribute(.unique) var id: UUID

    @Attribute(.unique) var accountId: UUID

    @Attribute(.unique) var username: String?

    init(
        accountId: UUID,
        username: String? = nil,
    ) {
        self.id = UUID()
        self.accountId = accountId
        self.username = username
    }
}
