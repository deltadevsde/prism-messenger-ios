//
//  AppContext.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation
import SwiftData


// Helper to manage shared ModelContainer
enum SwiftDataConfig {
    static var sharedModelContainer: ModelContainer = {
        do {
            let schema = Schema([User.self, Chat.self, MessageData.self])
            let modelConfiguration = ModelConfiguration(
                isStoredInMemoryOnly: false
            )
            let modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            return modelContainer
        } catch {
            fatalError("Failed to create model container: \(error)")
        }
    }()
}

extension AppContext {
    
    static func createDefaultModelContext() -> ModelContext {
        return ModelContext(SwiftDataConfig.sharedModelContainer)
    }
    
    // Deletes the SwiftData store when schema changes require migration
    func resetSwiftDataStoreIfNeeded() {
        // Check if schema has changed - only delete database when needed
        let currentVersion = UserDefaults.standard.integer(forKey: UserDefaultsKeys.schemaVersionKey)
        // Current schema version
        let newVersion = 8
        
        if currentVersion < newVersion {
            // Only delete database when schema has changed since last launch
            resetSwiftDataStoreIfNeeded()
            // Update schema version for future checks
            UserDefaults.standard.set(newVersion, forKey: UserDefaultsKeys.schemaVersionKey)
        }
    }
    
    private func resetSwiftDataStoreIfExists() {
        let fileManager = FileManager.default
        guard let applicationSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
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


