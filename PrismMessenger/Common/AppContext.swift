//
//  AppContext.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation
import SwiftData

class AppContext: ObservableObject {
    // Make keyManager accessible since it's needed for X3DH processing
    let keyManager: KeyManager
    let backendGateway: BackendGatewayProtocol
    let chatManager: ChatManager
    let modelContext: ModelContext
    weak var appLaunch: AppLaunch?
    
    // Convenience properties for backward compatibility
    var signupService: RegistrationServiceProtocol { backendGateway.registrationService }
    var keyService: KeyServiceProtocol { backendGateway.keyService }
    var messageService: MessageServiceProtocol { backendGateway.messageService }
    
    init(modelContext: ModelContext) throws {
        self.modelContext = modelContext
        
        // Initialize KeyManager
        self.keyManager = KeyManager()
        
        // Create the BackendGateway
        let gateway = try BackendGateway(modelContext: modelContext)
        self.backendGateway = gateway
        
        // Initialize ChatManager
        self.chatManager = ChatManager(modelContext: modelContext)
        
        // Set appLaunch property for ChatManager (will be updated after init)
        chatManager.appLaunch = appLaunch
        
        // Set circular references
        gateway.setAppContext(self)
    }
    
    // Update appLaunch reference
    func setAppLaunch(_ appLaunch: AppLaunch) {
        self.appLaunch = appLaunch
        chatManager.appLaunch = appLaunch
        
        // Update appLaunch in BackendGateway
        if let gateway = backendGateway as? BackendGateway {
            gateway.setAppLaunch(appLaunch)
        }
    }
    
    func createX3DHSession() throws -> X3DH {
        return X3DH(keyManager: keyManager)
    }
    
    /// Fetches new messages from the server and processes them
    /// - Returns: The number of new messages processed
    @MainActor
    func fetchAndProcessMessages() async throws -> Int {
        // Get the currently selected username from appLaunch, or fall back to the first user
        guard let username = appLaunch?.selectedUsername else {
            // Fallback to first user if appLaunch.selectedUsername is not set
            let descriptor = FetchDescriptor<UserData>()
            let users = try modelContext.fetch(descriptor)
            guard let user = users.first else {
                return 0
            }
            
            return try await processMessagesForUser(user.username)
        }
        
        return try await processMessagesForUser(username)
    }
    
    /// Helper method to process messages for a specific username
    @MainActor
    private func processMessagesForUser(_ username: String) async throws -> Int {
        
        do {
            // 1. Fetch new messages from the server
            let messages = try await messageService.fetchMessages(for: username)
            
            if messages.isEmpty {
                return 0
            }
            
            // 2. Process the messages and get the IDs of processed messages
            let processedIds = try await messageService.processReceivedMessages(
                messages: messages,
                currentUser: username,
                chatManager: chatManager
            )
            
            if !processedIds.isEmpty {
                // 3. Mark the processed messages as delivered on the server
                try await messageService.markMessagesAsDelivered(
                    messageIds: processedIds,
                    for: username
                )
            }
            
            return processedIds.count
        } catch {
            return 0
        }
    }
    
    /// Get the current user data
    /// - Returns: The current user's UserData
    @MainActor
    private func getCurrentUserData() throws -> UserData {
        guard let selectedUsername = appLaunch?.selectedUsername else {
            throw MessageError.unauthorized
        }
        
        let descriptor = FetchDescriptor<UserData>(
            predicate: #Predicate<UserData> { user in
                user.username == selectedUsername
            }
        )
        
        let users = try modelContext.fetch(descriptor)
        guard let currentUser = users.first else {
            throw MessageError.unauthorized
        }
        
        return currentUser
    }
}
