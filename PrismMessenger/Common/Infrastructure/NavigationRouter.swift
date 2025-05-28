//
//  NavigationRouter.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import SwiftUI

private let log = Log.common

enum LaunchState {
    case loading
    case unregistered
    case registered
    case error
}

enum Route: Hashable {
    case chat(Chat)
    case profile(UUID)
    case registration
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
            resetPath()
        }

        launchState = newLaunchState
    }

    func resetPath() {
        path = []
    }

    func navigateTo(_ route: Route) {
        guard activeRoute != route else {
            log.warning("Route already active: \(String(describing: route))")
            return
        }

        path.append(route)
    }

    func openChat(_ chat: Chat) {
        // If another chat is open, dismiss it first
        if case let .chat(alreadyOpenChat) = activeRoute, chat != alreadyOpenChat {
            path.removeLast()
        }

        navigateTo(.chat(chat))
    }

    func openProfile(_ profileId: UUID) {
        // If another profile is open, dismiss it first
        if case let .profile(alreadyOpenProfileId) = activeRoute, profileId != alreadyOpenProfileId
        {
            path.removeLast()
        }

        navigateTo(.profile(profileId))
    }
}
