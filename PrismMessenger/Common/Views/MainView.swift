//
//  ContentView.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import SwiftUI
import SwiftData

struct MainView: View {
    @EnvironmentObject private var appContext: AppContext
    @EnvironmentObject private var appLaunch: AppLaunch
    
    @State private var path = NavigationPath()
    @State private var messagePollingTask: Task<Void, Never>?
    @State private var lastMessageCheckTime = Date()
    
    var body: some View {
        NavigationStack(path: $path) {
            Group {
                switch appLaunch.launchState {
                case .loading:
                    LoadingView()
                        .navigationTitle("")
                case .unregistered:
                    FeaturesView(path: $path)
                        .navigationTitle("Welcome")
                case .ready:
                    mainContentView
                case .error:
                    errorView
                }
            }
        }
        .onChange(of: appLaunch.launchState) { oldState, newState in
            if oldState != newState && newState == .ready {
                // Reset navigation path when transitioning to ready state
                path = NavigationPath()
            }
        }
        .modelContext(appContext.modelContext)
        .environmentObject(appContext.appLaunch)
        .environmentObject(appContext.chatService)
        .environmentObject(appContext.messageService)
        .environmentObject(appContext.registrationService)
        .environmentObject(appContext.userService)
        .environmentObject(appContext.updatePushTokenService)
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
        .onAppear {
            // Reset navigation path when error view appears
            path = NavigationPath()
        }
    }
}

#Preview {
    MainView()
        .environmentObject(AppContext.forPreview())
}
