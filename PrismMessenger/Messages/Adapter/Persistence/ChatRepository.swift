//
//  ChatRepository.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation
import SwiftData

protocol ChatRepository {
    func getAllChats(for username: String) async throws -> [Chat]
    func getChat(withId id: UUID) async throws -> Chat?
    func getChat(withParticipant participantUsername: String, forOwner ownerUsername: String) async throws -> Chat?
    func saveChat(_ chat: Chat) async throws
    func deleteChat(_ chat: Chat) async throws
}

@MainActor
class SwiftDataChatRepository: ChatRepository {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func getAllChats(for username: String) async throws -> [Chat] {
        let descriptor = FetchDescriptor<Chat>(
            predicate: #Predicate<Chat> { chat in
                chat.ownerUsername == username
            }
        )
        
        return try modelContext.fetch(descriptor)
    }
    
    func getChat(withId id: UUID) async throws -> Chat? {
        let descriptor = FetchDescriptor<Chat>(
            predicate: #Predicate<Chat> { chat in
                chat.id == id
            },
            sortBy: [SortDescriptor(\.lastMessageTimestamp, order: .reverse)]
        )
        
        let chats = try modelContext.fetch(descriptor)
        return chats.first
    }
    
    func getChat(withParticipant participantUsername: String, forOwner ownerUsername: String) async throws -> Chat? {
        let descriptor = FetchDescriptor<Chat>(
            predicate: #Predicate<Chat> { chat in
                chat.participantUsername == participantUsername && chat.ownerUsername == ownerUsername
            }
        )
        
        let chats = try modelContext.fetch(descriptor)
        return chats.first
    }
    
    func saveChat(_ chat: Chat) async throws {
        modelContext.insert(chat)
        try modelContext.save()
    }
    
    func deleteChat(_ chat: Chat) async throws {
        modelContext.delete(chat)
        try modelContext.save()
    }
}
