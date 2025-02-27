//
//  UserData.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//
import SwiftData
import Foundation
import CryptoKit

@Model
final class UserData: Identifiable {
    @Attribute(.unique) var username: String
    var displayName: String?
    
    private(set) var signedPrekey: CryptoPayload
    private var prekeys: [PrivatePrekey]
    private var prekeyCounter: UInt64 = 0
    
    init(signedPrekey: P256.Signing.PrivateKey, username: String, displayName: String? = nil) {
        self.signedPrekey = signedPrekey.toCryptoPayload()
        self.prekeys = []
        self.prekeyCounter = 0
        self.username = username
        self.displayName = displayName
    }
    
    func addPrekeys(keys: [P256.Signing.PrivateKey]) throws {
        for key in keys {
            prekeys.append(PrivatePrekey(key_idx: prekeyCounter, key: key.toCryptoPayload()))
            prekeyCounter += 1
        }
    }
    
    func getPrekey(keyIdx: UInt64) throws -> P256.Signing.PrivateKey? {
        let prekey = prekeys.first { $0.key_idx == keyIdx }
        return try prekey?.key.toP256PrivateKey()
    }
    
    /// Deletes the `Prekey` with the given index. To be called when a prekey is used by a conversation partner to initiate a conversation.
    func deletePrekey(keyIdx: UInt64) {
        prekeys.removeAll { $0.key_idx == keyIdx }
    }
    
    func getPublicPrekeys() throws -> [Prekey] {
        var publicPrekeys: [Prekey] = []
        for prekey in prekeys {
            publicPrekeys.append(Prekey(key_idx: prekey.key_idx, key: try prekey.key.toP256PrivateKey().publicKey))
        }
        return publicPrekeys
    }
}

@Model
final class ChatData: Identifiable {
    @Attribute(.unique) var id: UUID
    var participantUsername: String
    var displayName: String?
    var imageURL: String?
    var lastMessage: String?
    var lastMessageTimestamp: Date?
    var unreadCount: Int
    
    // Owner of this chat (the user who created it)
    var ownerUsername: String
    
    // Crypto session state (serialized)
    var doubleRatchetSession: Data
    
    // Messages in this chat
    @Relationship(deleteRule: .cascade) var messages: [MessageData] = []
    
    init(participantUsername: String, 
         ownerUsername: String,
         displayName: String? = nil,
         imageURL: String? = nil,
         doubleRatchetSession: Data) {
        self.id = UUID()
        self.participantUsername = participantUsername
        self.ownerUsername = ownerUsername
        self.displayName = displayName
        self.imageURL = imageURL
        self.doubleRatchetSession = doubleRatchetSession
        self.unreadCount = 0
    }
    
    func addMessage(_ message: MessageData) {
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

@Model
final class MessageData: Identifiable {
    @Attribute(.unique) var id: UUID
    var content: String
    var timestamp: Date
    var isFromMe: Bool
    var status: MessageStatus
    
    // Server-related properties
    var serverId: UUID?
    var serverTimestamp: Date?
    
    // Reference back to parent chat
    var chat: ChatData?
    
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

extension ModelContext {
    var sqliteCommand: String {
        if let url = container.configurations.first?.url.path(percentEncoded: false) {
            "sqlite3 \"\(url)\""
        } else {
            "No SQLite database found."
        }
    }
}
