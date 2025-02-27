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
