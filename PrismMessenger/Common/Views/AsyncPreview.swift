//
//  AsyncPreview.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import SwiftUI

struct AsyncPreview<Content: View>: View {
    @StateObject private var appContext = AppContextFactory.forTest()

    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate

    @State private var isLoaded = false

    private var content: () -> Content
    private var setupTask: ((AppContext) async throws -> Void)?

    init(
        @ViewBuilder content: @escaping () -> Content,
        withSetup setupTask: ((AppContext) async throws -> Void)? = nil
    ) {
        self.content = content
        self.setupTask = setupTask
    }

    var body: some View {
        Group {
            if isLoaded {
                NavigationStack(path: $appContext.router.path) {
                    content()
                        .navigationBarBackButtonHidden()
                        .navigationDestination(for: Route.self) {
                            if case let .chat(targetChat) = $0 {
                                ChatView(chat: targetChat)
                            } else if case let .profile(userId) = $0 {
                                ProfileView(userId: userId)
                            }
                        }
                }
                .modelContext(appContext.modelContext)
                .environment(appContext.presenceService)
                .environment(appContext.typingService)
                .environment(appContext.ownProfileService)
                .environment(appContext.profileCacheService)
                .environment(appContext.profilePictureCacheService)
                .environmentObject(appContext)
                .environmentObject(appContext.router)
                .environmentObject(appContext.chatService)
                .environmentObject(appContext.messageService)
                .environmentObject(appContext.registrationService)
                .environmentObject(appContext.userService)
                .environmentObject(appContext.updatePushTokenService)
                .tint(.black)
            } else {
                Text("Waiting for async setup...")
            }
        }
        .task {
            do {
                appContext.connectAppDelegate(appDelegate)
                await startApp(appContext: appContext)
                try await setupTask?(appContext)
                isLoaded = true
            } catch {
                print("Preview setup failed: \(error)")
            }
        }
    }

}
