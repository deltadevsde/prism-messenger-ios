//
//  PrismMessengerApp.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import SwiftUI
import SwiftData

@main
struct PrismMessengerApp: App {
    @State private var appContext: AppContext?
    @StateObject private var appLaunch = AppLaunch()
    
    init() {
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
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if let appContext = appContext {
                    MainView()
                        .environmentObject(appContext)
                        .environmentObject(appLaunch)
                } else {
                    LoadingView()
                        .onAppear {
                            initializeAppContext()
                        }
                }
            }
            .modelContainer(for: [UserData.self, ChatData.self, MessageData.self])
        }
    }
    
    private func initializeAppContext() {
        // Access modelContext asynchronously to avoid potential SwiftData initialization issues
        Task { @MainActor in
            do {
                // Get a ModelContext from the environment
                let context = ModelContext(SwiftDataConfig.sharedModelContainer)
                
                // Create AppContext first to initialize UserManager
                let appContext = try AppContext(modelContext: context)
                
                // Initialize AppLaunch with the UserManager
                await appLaunch.initialize(modelContext: context, userManager: appContext.userManager)
                
                // Set the initialized AppLaunch in AppContext
                appContext.setAppLaunch(appLaunch)
                self.appContext = appContext
            } catch {
                print("Failed to initialize AppContext: \(error)")
                // TODO: Show error to user
            }
        }
    }
}


// Helper to manage shared ModelContainer
enum SwiftDataConfig {
    static var sharedModelContainer: ModelContainer = {
        do {
            let schema = Schema([UserData.self, ChatData.self, MessageData.self])
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

// MARK: - User Defaults Keys
private enum UserDefaultsKeys {
    static let schemaVersionKey = "PrismMessenger.SchemaVersion"
}

// Deletes the SwiftData store when schema changes require migration
private func resetSwiftDataStoreIfNeeded() {
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
