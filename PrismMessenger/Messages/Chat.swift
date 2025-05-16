//
//  Chat.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation
import SwiftData

@Model
final class Chat: Identifiable {
    @Attribute(.unique) var id: UUID
    var participantId: UUID
    var displayName: String?
    var imageURL: String?
    var lastMessage: String?
    var lastMessageTimestamp: Date?
    var unreadCount: Int

    // Crypto session state (serialized)
    var doubleRatchetSession: Data

    // Messages in this chat
    @Relationship(deleteRule: .cascade) var messages: [Message] = []

    init(
        participantId: UUID,
        displayName: String? = nil,
        imageURL: String? = nil,
        doubleRatchetSession: Data
    ) {
        self.id = UUID()
        self.participantId = participantId
        self.displayName = displayName
        self.imageURL = imageURL
        self.doubleRatchetSession = doubleRatchetSession
        self.unreadCount = 0
    }

    func addMessage(_ message: Message) {
        messages.append(message)
        lastMessage = message.content
        lastMessageTimestamp = message.timestamp

        // Increment unread count if message is from other user
        if !message.isFromMe {
            unreadCount += 1
        }
    }

    func markAsRead() {
        unreadCount = 0
    }
}
