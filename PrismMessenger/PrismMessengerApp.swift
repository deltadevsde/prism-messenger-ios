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
    let container: ModelContainer = try! ModelContainer(for: UserData.self, ChatData.self, MessageData.self)
    @State private var appContext: AppContext?
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if let appContext = appContext {
                    MainView()
                        .environmentObject(appContext)
                } else {
                    LoadingView()
                        .onAppear {
                            initializeAppContext()
                        }
                }
            }
            .modelContainer(container)
        }
    }
    
    private func initializeAppContext() {
        // Access modelContext asynchronously to avoid potential SwiftData initialization issues
        Task { @MainActor in
            do {
                let context = ModelContext(container)
                let appContext = try AppContext(modelContext: context)
                self.appContext = appContext
            } catch {
                print("Failed to initialize AppContext: \(error)")
                // TODO: Show error to user
            }
        }
    }
}
