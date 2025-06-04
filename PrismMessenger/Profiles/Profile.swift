//
//  ProfileEntities.swift
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
    var displayName: String?
    var picture: String?

    init(
        accountId: UUID,
        username: String,
        displayName: String? = nil,
        picture: String? = nil
    ) {
        self.accountId = accountId
        self.username = username
        self.displayName = displayName
        self.picture = picture
    }
}
