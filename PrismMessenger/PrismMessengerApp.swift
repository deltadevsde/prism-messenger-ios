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
    let container: ModelContainer = try! ModelContainer(for: UserData.self)

    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .modelContainer(container)
    }
}
