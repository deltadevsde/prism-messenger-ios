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
    @StateObject private var appContext = AppContext.forProd()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(appContext)
                .environmentObject(appContext.appLaunch)
                .task {
                    await appContext.onAppStart()
                }
        }
    }
}

