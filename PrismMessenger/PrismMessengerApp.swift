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

    @StateObject private var appContext: AppContext = isTesting ? .forPreview() : .forProd()

    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(appContext)
                .environmentObject(appContext.appLaunch)
                .task {
                    await appContext.onAppStart()
                }
                .onAppear {
                    appDelegate.setServices(
                        pushNotificationService: appContext.pushNotificationService,
                        messageService: appContext.messageService
                    )
                }
        }
    }
}
