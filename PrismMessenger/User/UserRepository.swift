//
//  UserRepository.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import CryptoKit
import Foundation
import SwiftData

@MainActor
protocol UserRepository {
    func getUser() async throws -> User?
    func saveUser(_ user: User) async throws
}

@MainActor
class SwiftDataUserRepository: UserRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func getUser() async throws -> User? {
        let descriptor = FetchDescriptor<User>()
        return try modelContext.fetch(descriptor).first
    }

    func saveUser(_ user: User) async throws {
        modelContext.insert(user)
        try modelContext.save()
    }
}
