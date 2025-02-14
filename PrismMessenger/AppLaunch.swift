//
//  AppLaunch.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation


@MainActor
class AppLaunch: ObservableObject {
    enum LoadingState {
        case loading
        case unregistered
        case ready
        case error
    }
    
    @Published private(set) var state: LoadingState = .loading
    
    func initialize() async {
        state = .loading
        do {
            try await Task.sleep(nanoseconds: 1500000000)
            // For now, we just assume
            state = .unregistered
        } catch {
            state = .error
        }
    }
    
    func setRegistered() async {
        state = .ready
    }
}
