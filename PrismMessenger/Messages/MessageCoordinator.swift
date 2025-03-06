//
//  MessageCoordinator.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation
import SwiftData

protocol MessageCoordination {
    func startMessagePolling()
    func stopMessagePolling()
    func fetchAndProcessMessages() async throws -> Int
}

class MessageCoordinator: MessageCoordination {
    private let messageService: MessageService
    private let chatManager: ChatManager
    private let userManager: UserManager
    private var messagePollingTask: Task<Void, Never>?
    private let pollingInterval: UInt64 = 5_000_000_000 // 5 seconds
    
    init(messageService: MessageService, chatManager: ChatManager, userManager: UserManager) {
        self.messageService = messageService
        self.chatManager = chatManager
        self.userManager = userManager
    }
    
    func startMessagePolling() {
        stopMessagePolling()
        
        messagePollingTask = Task {
            while !Task.isCancelled {
                do {
                    let newMessageCount = try await fetchAndProcessMessages()
                    if newMessageCount > 0 {
                        print("Fetched \(newMessageCount) new messages")
                    }
                } catch {
                    print("Error fetching messages: \(error)")
                }
                
                try? await Task.sleep(nanoseconds: pollingInterval)
            }
        }
    }
    
    func stopMessagePolling() {
        messagePollingTask?.cancel()
        messagePollingTask = nil
    }
    
    @MainActor
    func fetchAndProcessMessages() async throws -> Int {
        do {
            // Get the current username
            let username = try userManager.getCurrentUsername()
            
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
            print("Error in message processing: \(error)")
            return 0
        }
    }
}