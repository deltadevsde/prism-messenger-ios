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
    @State private var messagePollingTask: Task<Void, Never>?
    @State private var lastMessageCheckTime = Date()
    
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
        // We're now initializing in PrismMessengerApp instead
        // to ensure proper initialization order
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
        .onAppear {
            // Start message polling when tab view appears
            startMessagePolling()
        }
        .onDisappear {
            // Stop message polling when tab view disappears
            stopMessagePolling()
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
                    // We have direct access to appContext as an @EnvironmentObject
                    await appLaunch.initialize(modelContext: modelContext, userManager: appContext.userManager)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    // Start polling for new messages
    private func startMessagePolling() {
        // Cancel any existing task
        messagePollingTask?.cancel()
        
        // Create a new task for message polling
        messagePollingTask = Task {
            while !Task.isCancelled {
                do {
                    let newMessageCount = try await appContext.messageService.fetchAndProcessMessages()
                    if newMessageCount > 0 {
                        print("Fetched \(newMessageCount) new messages")
                    }
                } catch {
                    print("Error fetching messages: \(error)")
                }
                
                // Wait 5 seconds before polling again
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
    }
    
    // Stop polling for new messages
    private func stopMessagePolling() {
        messagePollingTask?.cancel()
        messagePollingTask = nil
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: UserData.self, ChatData.self, MessageData.self, configurations: config)
    let context = ModelContext(container)
    
    // Create a context for preview
    let appContext = try! AppContext(modelContext: context)
    
    // Create AppLaunch
    let appLaunch = AppLaunch()
    
    return MainView()
        .modelContainer(container)
        .environmentObject(appContext)
        .environmentObject(appLaunch)
}
