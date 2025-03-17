//
//  Message.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import SwiftData
import Foundation


@Model
final class Message: Identifiable {
    @Attribute(.unique) var id: UUID
    var content: String
    var timestamp: Date
    var isFromMe: Bool
    var status: MessageStatus
    
    // Server-related properties
    var serverId: UUID?
    var serverTimestamp: Date?
    
    // Reference back to parent chat
    var chat: Chat?
    
    init(content: String, isFromMe: Bool, status: MessageStatus = .sent) {
        self.id = UUID()
        self.content = content
        self.timestamp = Date()
        self.isFromMe = isFromMe
        self.status = status
    }
}

enum MessageStatus: String, Codable {
    case sending
    case sent
    case delivered
    case read
    case failed
}
