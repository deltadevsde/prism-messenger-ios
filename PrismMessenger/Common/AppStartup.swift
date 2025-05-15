//
//  AppStartup.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

@MainActor
func startApp(appContext: AppContext, router: NavigationRouter) async {
    router.setLaunchState(.loading)
    do {
        ModelContextProvider.resetSwiftDataStoreIfNeeded()

        try await appContext.userService.loadUser()
        let userExists = appContext.userService.currentUser != nil

        if userExists {
            router.setLaunchState(.registered)
            try await appContext.updatePushTokenService.updatePushToken()
        } else {
            router.setLaunchState(.unregistered)
        }

        print("LaunchState is: \(router.launchState)")
    } catch {
        router.setLaunchState(.error)
    }
}
