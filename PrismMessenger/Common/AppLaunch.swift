//
//  AppLaunch.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation
import SwiftData


@MainActor
class AppLaunch: ObservableObject {
    enum LoadingState {
        case loading
        case unregistered
        case ready
        case error
    }
    
    @Published private(set) var state: LoadingState = .loading
    
    func setLoading() {
        state = .loading
    }
    
    func setUnregistered() {
        state = .unregistered
    }
    
    func setRegistered() {
        state = .ready
    }
    
    func setError() {
        state = .error
    }
}
