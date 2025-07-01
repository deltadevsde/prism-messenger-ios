//
//  ConnectionService.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Combine
import Foundation
import SwiftUI

private let log = Log.common

/// Service that manages WebSocket connections based on app lifecycle and state
@MainActor
class ConnectionService: ObservableObject {
    private let realTimeCommunication: RealTimeCommunication
    private let scenePhaseRepository: ScenePhaseRepository

    @Published private(set) var isConnected = false

    /// Whether the connection should be maintained based on app state
    private var shouldMaintainConnection: Bool {
        switch scenePhaseRepository.currentPhase {
        case .active:
            return true
        case .inactive, .background:
            return false
        @unknown default:
            return false
        }
    }

    init(
        realTimeCommunication: RealTimeCommunication,
        scenePhaseRepository: ScenePhaseRepository
    ) {
        self.realTimeCommunication = realTimeCommunication
        self.scenePhaseRepository = scenePhaseRepository

        // Monitor scene phase changes
        startMonitoringScenePhase()
    }

    /// Connect to real-time communication if conditions are met
    func connect() async {
        guard shouldMaintainConnection else {
            log.debug("Not connecting - app not in active state")
            return
        }

        guard !isConnected else {
            log.debug("Already connected")
            return
        }

        log.info("Establishing real-time connection")
        await realTimeCommunication.connect()
        isConnected = true
    }

    /// Force connection regardless of app state (e.g., for background message processing)
    func forceConnect() async {
        guard !isConnected else {
            log.debug("Already connected")
            return
        }

        log.info("Force establishing real-time connection")
        await realTimeCommunication.connect()
        isConnected = true
    }

    /// Disconnect from real-time communication
    func disconnect() {
        guard isConnected else {
            log.debug("Already disconnected")
            return
        }

        log.info("Disconnecting real-time connection")
        realTimeCommunication.disconnect()
        isConnected = false
    }

    /// Connect when a push notification is received while in background
    func handleBackgroundPushNotification() async {
        log.info("Handling background push notification - establishing temporary connection")
        await forceConnect()
    }

    // MARK: - Private Methods

    private func startMonitoringScenePhase() {
        // Use Combine to observe scene phase changes
        scenePhaseRepository.$currentPhase
            .sink { [weak self] newPhase in
                Task { @MainActor in
                    await self?.handleScenePhaseChange(newPhase)
                }
            }
            .store(in: &cancellables)
    }

    private func handleScenePhaseChange(_ newPhase: ScenePhase) async {
        log.debug("Adjusting connection (scene phase: \(String(describing: newPhase))")

        switch newPhase {
        case .active:
            // App became active - establish connection
            await connect()

        case .inactive, .background:
            // App went to background - disconnect to save resources
            disconnect()
            break

        @unknown default:
            log.warning(
                "Not changing connection. Unknown scene phase: \(String(describing: newPhase))"
            )
        }
    }

    // Store cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
}

// MARK: - Extensions

extension ConnectionService {
    /// Convenience method to check if connection should be established
    var shouldConnect: Bool {
        shouldMaintainConnection && !isConnected
    }
}
