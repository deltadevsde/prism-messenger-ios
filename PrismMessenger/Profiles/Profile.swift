//
//  Profile.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation
import SwiftData


@Model
final class Profile: Identifiable {
    var id: UUID { accountId }
    @Attribute(.unique) var accountId: UUID
    @Attribute(.unique) var username: String

    init(
        accountId: UUID,
        username: String,
    ) {
        self.accountId = accountId
        self.username = username
    }
}
