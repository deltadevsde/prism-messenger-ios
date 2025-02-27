//
//  AppContext.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation
import SwiftData

class AppContext: ObservableObject {
    private let keyManager: KeyManager
    private let restClient: RestClient
    let signupService: RegistrationService
    let keyService: KeyService
    let chatManager: ChatManager
    let messageService: MessageService
    let modelContext: ModelContext
    weak var appLaunch: AppLaunch?
    
    init(modelContext: ModelContext) throws {
        self.modelContext = modelContext
        let restClient = try RestClient(baseURLStr: "http://127.0.0.1:48080")
        self.restClient = restClient
        
        keyManager = KeyManager()
        signupService = RegistrationService(restClient: restClient, keyManager: keyManager)
        keyService = KeyService(restClient: restClient, keyManager: keyManager)
        chatManager = ChatManager(modelContext: modelContext)
        chatManager.appLaunch = appLaunch
        messageService = MessageService(restClient: restClient, modelContext: modelContext)
        messageService.appLaunch = appLaunch
    }
    
    func createX3DHSession() throws -> X3DH {
        return X3DH(keyManager: keyManager)
    }
    
    /// Fetches new messages from the server and processes them
    /// - Returns: The number of new messages processed
    @MainActor
    func fetchAndProcessMessages() async throws -> Int {
        // Get the first user from the database
        let descriptor = FetchDescriptor<UserData>()
        let users = try modelContext.fetch(descriptor)
        guard let user = users.first else {
            return 0
        }
        
        let username = user.username
        
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
