//
//  ChatRepository.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation
import SwiftData

@MainActor
protocol ChatRepository {
    func getAllChats() async throws -> [Chat]
    func getChat(withId id: UUID) async throws -> Chat?
    func getChat(withParticipant participantId: UUID) async throws -> Chat?
    func saveChat(_ chat: Chat) async throws
    func deleteChat(_ chat: Chat) async throws
}

@MainActor
class SwiftDataChatRepository: ChatRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func getAllChats() async throws -> [Chat] {
        let descriptor = FetchDescriptor<Chat>(
            sortBy: [SortDescriptor(\.lastMessageTimestamp, order: .reverse)]
        )

        return try modelContext.fetch(descriptor)
    }

    func getChat(withId id: UUID) async throws -> Chat? {
        let descriptor = FetchDescriptor<Chat>(
            predicate: #Predicate<Chat> { chat in
                chat.id == id
            }
        )
        let chats = try modelContext.fetch(descriptor)
        return chats.first
    }

    func getChat(withParticipant participantId: UUID)
        async throws -> Chat?
    {
        let descriptor = FetchDescriptor<Chat>(
            predicate: #Predicate<Chat> { chat in
                chat.participantId == participantId
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
