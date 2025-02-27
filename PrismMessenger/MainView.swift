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
    @StateObject private var appLaunch = AppLaunch()
    @Environment(\.modelContext) private var modelContext
    
    @EnvironmentObject private var appContext: AppContext
    @State private var messagePollingTask: Task<Void, Never>?
    @State private var lastMessageCheckTime = Date()
    
    var body: some View {
            NavigationStack(path: $path) {
                switch appLaunch.state {
                case .loading:
                    LoadingView()
                case .unregistered:
                    FeaturesView(path: $path)
                case .ready:
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
                case .error:
                    Text("Error loading content")
                        .foregroundColor(.red)
                }
            }
            .navigationTitle("Messenger")
            .task {
                await appLaunch.initialize()
            }
            .environmentObject(appLaunch)
            // We'll inject the appContext from PrismMessengerApp instead
    }
    
    // Start polling for new messages
    private func startMessagePolling() {
        // Cancel any existing task
        messagePollingTask?.cancel()
        
        // Create a new task for message polling
        messagePollingTask = Task {
            while !Task.isCancelled {
                do {
                    let newMessageCount = try await appContext.fetchAndProcessMessages()
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
    
    return MainView()
        .modelContainer(container)
        .environmentObject(appContext)
}
