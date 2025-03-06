//
//  ContentView.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import SwiftUI
import SwiftData

struct MainView: View {
    @State private var path = NavigationPath()
    @EnvironmentObject private var appLaunch: AppLaunch
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appContext: AppContext
    
    var body: some View {
        NavigationStack(path: $path) {
            Group {
                switch appLaunch.state {
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
        }
        .onAppear {
            // Start message polling when tab view appears
            appContext.messageCoordinator.startMessagePolling()
        }
        .onDisappear {
            // Stop message polling when tab view disappears
            appContext.messageCoordinator.stopMessagePolling()
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
                    await appLaunch.initialize(
                        modelContext: modelContext,
                        userManager: appContext.userManager
                    )
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

// Preview removed temporarily for testing
