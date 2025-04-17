//
//  AppLaunch.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation
import SwiftData

enum LaunchState {
    case loading
    case unregistered
    case ready
    case error
}

@MainActor
class AppLaunch: ObservableObject {

    @Published var launchState: LaunchState = .loading

}
