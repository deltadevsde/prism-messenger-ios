//
//  ProfilePicture.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation
import SwiftData

@Model
final class ProfilePicture: Identifiable {
    var id: String { path }

    @Attribute(.unique)
    var path: String

    @Attribute(.externalStorage)
    var data: Data

    var updatedAt: Date

    init(
        path: String,
        data: Data
    ) {
        self.path = path
        self.data = data
        self.updatedAt = Date()
    }
}
