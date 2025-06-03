//
//  LightClientService.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation
import PrismLightClient

private let log = Log.forCategory("lightclient")

@MainActor
class LightClientService: ObservableObject {
    @Published var isVerified = false
    @Published var logs: [String] = []
    @Published var progress: Double = 0.0
    @Published var status: String = "Not initialized"
    @Published var currentCommitment: String?
    @Published var currentHeight: UInt64 = 0
    
    private var client: LightClient?
    private var eventTask: Task<Void, Never>?
    
    private var debugLogHandler: ((String) -> Void)?
    private let maxLogsInMemory = 100
    
    // Configuration
    private let network = "specter"
    private let startHeight: UInt64 = 6461140
    
    init() {
        addLog("LightClientService initialized")
    }
    
    deinit {
        eventTask?.cancel()
    }
    
    func setDebugLogHandler(_ handler: @escaping (String) -> Void) {
        debugLogHandler = handler
    }
    
    func clearDebugLogHandler() {
        debugLogHandler = nil
    }
    
    private func addLog(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(),
                                                     dateStyle: .none,
                                                     timeStyle: .medium)
        let logEntry = "[\(timestamp)] \(message)"
        
        // Send to debug handler if attached
        debugLogHandler?(logEntry)
        
        logs.append(logEntry)
        if logs.count > maxLogsInMemory {
            logs.removeFirst(logs.count - maxLogsInMemory)
        }
        
        log.debug("\(message)")
    }
    
    func initialize() async {
        addLog("Starting light client initialization...")
        status = "Initializing..."
        
        do {
            // Get the documents directory for storing light client data
            let documentsPath = FileManager.default.urls(for: .documentDirectory,
                                                         in: .userDomainMask).first!
            let basePath = documentsPath.appendingPathComponent("prism_lightclient").path
            
            // Create directory if it doesn't exist
            try? FileManager.default.createDirectory(atPath: basePath,
                                                     withIntermediateDirectories: true)
            
            addLog("Network: \(network)")
            addLog("Start height: \(startHeight)")
            
            // Initialize the UniFFI light client
            client = try await LightClient(
                networkName: network,
                startHeight: startHeight,
                basePath: basePath
            )
            
            addLog("✅ Light client created successfully")
            addLog("Starting sync...")
            status = "Starting sync..."
            progress = 0.2
            
            // Start the light client
            Task.detached(priority: .background) { [weak self] in
                do {
                    try await self?.client?.start()
                } catch {
                    await MainActor.run { [weak self] in
                        self?.addLog("❌ Light client stopped: \(error)")
                    }
                }
            }
            
            eventTask = Task.detached { [weak self] in
                await self?.pollEvents()
            }
            
            // Check for current commitment
            await updateCurrentCommitment()
            
        } catch {
            addLog("❌ Failed to initialize: \(error)")
            status = "Error: \(error.localizedDescription)"
        }
    }
    
    @MainActor
    private func pollEvents() async {
        while !Task.isCancelled {
            do {
                if let event = try await client?.nextEvent() {
                    // Process event
                    await handleEvent(event)
                }
            } catch {
                // Log error but continue polling
                addLog("Event polling error: \(error)")
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms delay
            }
        }
    }
    
    private func handleEvent(_ event: UniffiLightClientEvent) async {
        switch event {
        case .syncStarted(let height):
            addLog("🔄 Sync started at height \(height)")
            currentHeight = height
            progress = 0.3
            
        case .updateDaHeight(let height):
            addLog("📊 DA height updated: \(height)")
            currentHeight = height
            
        case .epochVerificationStarted(let height):
            addLog("🔍 Verifying epoch at height \(height)")
            status = "Verifying epoch \(height)..."
            progress = 0.5
            
        case .epochVerified(let height):
            addLog("✅ Epoch verified at height \(height)")
            status = "Verified up to height \(height)"
            progress = 0.8
            isVerified = true
            await updateCurrentCommitment()
            
        case .epochVerificationFailed(let height, let error):
            addLog("❌ Epoch verification failed at \(height): \(error)")
            status = "Verification failed"
            
        case .noEpochFound(let height):
            addLog("⚠️ No epoch found at height \(height)")
            
        case .getCurrentCommitment(let commitment):
            addLog("📝 Current commitment: \(commitment)")
            currentCommitment = commitment
            
        case .recursiveVerificationStarted(let height):
            addLog("🔄 Recursive verification started at \(height)")
            status = "Running recursive verification..."
            
        case .recursiveVerificationCompleted(let height):
            addLog("✅ Recursive verification completed at \(height)")
            progress = 1.0
            
        case .luminaEvent(let event):
            addLog("🌟 Lumina: \(event)")
            
        case .heightChannelClosed:
            addLog("⚠️ Height channel closed")
        }
    }
    
    private func updateCurrentCommitment() async {
        do {
            if let commitment = try await client?.getCurrentCommitment() {
                currentCommitment = commitment
                addLog("📝 Retrieved commitment: \(commitment)")
            }
        } catch {
            addLog("❌ Failed to get current commitment: \(error)")
        }
    }
    
    func retry() async {
        addLog("🔄 Retrying initialization...")
        isVerified = false
        progress = 0
        currentCommitment = nil
        currentHeight = 0
        eventTask?.cancel()
        await initialize()
    }
}
