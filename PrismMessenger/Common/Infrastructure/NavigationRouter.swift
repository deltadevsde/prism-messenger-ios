//
//  NavigationRouter.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import SwiftUI

enum LaunchState {
    case loading
    case unregistered
    case registered
    case error
}

enum Route: Hashable {
    case chat(Chat)
    case profile
    case registration
    case settings
}

@MainActor
class NavigationRouter: ObservableObject {

    @Published private(set) var launchState: LaunchState = .loading

    @Published var path: [Route] = []

    var activeRoute: Route? {
        path.last
    }

    func setLaunchState(_ newLaunchState: LaunchState) {
        if launchState != newLaunchState && [.registered, .error].contains(newLaunchState) {
            // Reset navigation path when transitioning to ready/error state
            path = []
        }

        launchState = newLaunchState
    }

    func navigateTo(_ route: Route) {
        path.append(route)
    }
}
