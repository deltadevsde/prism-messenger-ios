//
//  ContentView.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import SwiftData
import SwiftUI

struct MainView: View {
    @EnvironmentObject private var appContext: AppContext
    @EnvironmentObject private var router: NavigationRouter

    var body: some View {
        NavigationStack(path: $router.path) {
            Group {
                switch router.launchState {
                case .loading:
                    LoadingView()
                        .navigationTitle("")
                case .unregistered:
                    FeaturesView()
                        .navigationTitle("Welcome")
                case .registered:
                    mainContentView
                case .error:
                    errorView
                }
            }
        }
        .modelContext(appContext.modelContext)
        .environmentObject(appContext.router)
        .environmentObject(appContext.chatService)
        .environmentObject(appContext.messageService)
        .environmentObject(appContext.registrationService)
        .environmentObject(appContext.userService)
        .environmentObject(appContext.updatePushTokenService)
        .tint(.black)
    }

    private var profileIcon: some View {
        // TODO: Navigate to profile? Or what should this do?
        Image(systemName: "person.circle.fill")
            .font(.system(size: 40))
            .foregroundColor(.gray)
    }

    private var mainContentView: some View {
        TabView {
            ChatsView()
                .tabItem {
                    Label("Chats", systemImage: "message.fill")
                }

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
            // ContactsView() ?
            // CallsView() ?
        }
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                profileIcon
            }
            ToolbarItem(placement: .principal) {
                Image("prism_text")
            }
        }
    }

    private var errorView: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.red)

            Text("Error loading content")
                .font(.title)
                .foregroundColor(.red)

            Button("Try Again") {
                Task {
                    await appContext.onAppStart()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

#Preview {
    let context = AppContext.forPreview()
    let router = context.router

    router.setLaunchState(.registered)

    return MainView()
        .environmentObject(context)
        .environmentObject(router)
}
