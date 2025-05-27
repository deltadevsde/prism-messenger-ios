//
//  AppStartup.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

@MainActor
func startApp(appContext: AppContext) async {
    let router = appContext.router
    
    router.setLaunchState(.loading)
    do {
        ModelContextProvider.resetSwiftDataStoreIfNeeded()

        try await appContext.userService.loadUser()
        let userExists = appContext.userService.currentUser != nil

        if userExists {
            // Tasks to be done before launch screen disappears
            try await appContext.profileService.loadOwnProfile()

            router.setLaunchState(.registered)

            // Tasks to be done when user is already able to use the app
            try await appContext.updatePushTokenService.updatePushToken()
        } else {
            router.setLaunchState(.unregistered)
        }

        print("LaunchState is: \(router.launchState)")
    } catch {
        router.setLaunchState(.error)
    }
}
