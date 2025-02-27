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
    
    init(modelContext: ModelContext) throws {
        self.modelContext = modelContext
        let restClient = try RestClient(baseURLStr: "http://127.0.0.1:48080")
        self.restClient = restClient
        
        keyManager = KeyManager()
        signupService = RegistrationService(restClient: restClient, keyManager: keyManager)
        keyService = KeyService(restClient: restClient, keyManager: keyManager)
        chatManager = ChatManager(modelContext: modelContext)
        messageService = MessageService(restClient: restClient, modelContext: modelContext)
    }
    
    func createX3DHSession() throws -> X3DH {
        return X3DH(keyManager: keyManager)
    }
    
    /// Fetches new messages from the server and processes them
    /// - Returns: The number of new messages processed
    func fetchAndProcessMessages() async throws -> Int {
        // Get the current username
        let userData = try getCurrentUserData()
        
        // 1. Fetch new messages from the server
        let messages = try await messageService.fetchMessages(for: userData.username)
        
        if messages.isEmpty {
            return 0
        }
        
        // 2. Process the messages and get the IDs of processed messages
        let processedIds = try await messageService.processReceivedMessages(
            messages: messages,
            currentUser: userData.username,
            chatManager: chatManager
        )
        
        if !processedIds.isEmpty {
            // 3. Mark the processed messages as delivered on the server
            try await messageService.markMessagesAsDelivered(
                messageIds: processedIds,
                for: userData.username
            )
        }
        
        return processedIds.count
    }
    
    /// Get the current user data
    /// - Returns: The current user's UserData
    private func getCurrentUserData() throws -> UserData {
        let descriptor = FetchDescriptor<UserData>(predicate: nil)
        let users = try modelContext.fetch(descriptor)
        guard let currentUser = users.first else {
            throw MessageError.unauthorized
        }
        return currentUser
    }
}
