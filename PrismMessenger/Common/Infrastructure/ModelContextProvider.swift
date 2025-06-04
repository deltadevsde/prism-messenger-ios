//
//  ModelContextProvider.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation
import SwiftData

@MainActor
final class ModelContextProvider {

    static func createDefaultModelContext() -> ModelContext {
        return ModelContext(createModelContainer(inMemory: false))
    }

    static func createInMemoryModelContext() -> ModelContext {
        return ModelContext(createModelContainer(inMemory: true))
    }

    static private func createModelContainer(inMemory: Bool) -> ModelContainer {
        do {
            let schema = Schema([User.self, Chat.self, Message.self, Profile.self, ProfilePicture.self])
            let modelConfiguration = ModelConfiguration(
                isStoredInMemoryOnly: inMemory
            )
            let modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            return modelContainer
        } catch {
            fatalError("Failed to create model container: \(error)")
        }
    }

    // Deletes the SwiftData store when schema changes require migration
    static func resetSwiftDataStoreIfNeeded() {
        // Check if schema has changed - only delete database when needed
        let currentVersion = UserDefaults.standard.integer(
            forKey: UserDefaultsKeys.schemaVersionKey)
        // Current schema version
        let newVersion = 9

        if currentVersion < newVersion {
            // Only delete database when schema has changed since last launch
            resetSwiftDataStoreIfExists()
            // Update schema version for future checks
            UserDefaults.standard.set(newVersion, forKey: UserDefaultsKeys.schemaVersionKey)
        }
    }

    private static func resetSwiftDataStoreIfExists() {
        let fileManager = FileManager.default
        guard
            let applicationSupportURL = fileManager.urls(
                for: .applicationSupportDirectory, in: .userDomainMask
            ).first
        else {
            return
        }

        let storeURL = applicationSupportURL.appendingPathComponent("default.store")

        if fileManager.fileExists(atPath: storeURL.path) {
            do {
                try fileManager.removeItem(at: storeURL)
            } catch {
                print("Failed to delete the SwiftData store: \(error)")
            }
        }
    }
}
