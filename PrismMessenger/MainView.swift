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
    @StateObject private var appDependencies = try! AppContext()
    @StateObject private var appLaunch = AppLaunch()
    
    var body: some View {
            NavigationStack(path: $path) {
                switch appLaunch.state {
                case .loading:
                    LoadingView()
                case .unregistered:
                    FeaturesView(path: $path)
                case .ready:
                    TabView {
                        ChatsView().tabItem{Text("Chats")}
                        ProfileView().tabItem{Text("Profile")}
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
            .environmentObject(appDependencies.signupService)
            .environmentObject(appDependencies.keyService)
            .environmentObject(appLaunch)
            .environmentObject(appDependencies)
    }
}

#Preview {
    MainView()
}
