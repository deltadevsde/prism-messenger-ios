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
        .environmentObject(appContext.chatService)
        .environmentObject(appContext.messageService)
        .environment(appContext.ownProfileService)
        .environment(appContext.profileCacheService)
        .environment(appContext.profilePictureCacheService)
        .environmentObject(appContext.registrationService)
        .environmentObject(appContext.userService)
        .environmentObject(appContext.updatePushTokenService)
        .tint(.black)
    }

    private var mainContentView: some View {
        TabView {
            ChatsView()
                .tabItem {
                    Label("Chats", systemImage: "message.fill")
                }

            EditProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
            // ContactsView() ?
            // CallsView() ?
        }
        .navigationBarBackButtonHidden()
        .navigationDestination(for: Route.self) {
            if case let .chat(targetChat) = $0 {
                ChatView(chat: targetChat)
            } else if case let .profile(userId) = $0 {
                ProfileView(userId: userId)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                let uiImage: UIImage? = {
                    guard
                        let ownProfilePicturePath = appContext.ownProfileService.ownProfile?
                            .picture,
                        let ownProfilePicture = appContext.profilePictureCacheService
                            .profilePictures[ownProfilePicturePath],
                        let image = UIImage(data: ownProfilePicture.data)
                    else {
                        return nil
                    }
                    return image
                }()

                SmallProfilePictureView(uiImage: uiImage) {
                    // TODO: Open something like settings in the future
                }
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
                    await startApp(appContext: appContext)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

#Preview {
    @Previewable @StateObject var context: AppContext = AppContextFactory.forTest()
    @Previewable @StateObject var router = NavigationRouter()

    router.setLaunchState(.registered)

    return MainView()
        .environmentObject(context)
        .environmentObject(router)
}
