//
//  PrismMessengerApp.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import SwiftUI

@main
struct PrismMessengerApp: App {

    private static var isTesting = UserDefaults.standard.bool(forKey: UserDefaultsKeys.isTestingKey)

    @StateObject private var appContext: AppContext = Self.isTesting ? AppContextFactory.forTest() : AppContextFactory.forProd()
    @StateObject private var router = NavigationRouter()

    @Environment(\.scenePhase) private var scenePhase

    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(appContext)
                .environmentObject(router)
                .task {
                    appContext.connectAppDelegate(appDelegate)
                    await startApp(appContext: appContext, router: router)
                }
                .onChange(of: scenePhase) {
                    appContext.scenePhaseRepository.currentPhase = scenePhase
                }
        }
    }
}
