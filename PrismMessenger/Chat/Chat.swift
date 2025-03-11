import Foundation
import SwiftData

@Model
final class Chat: Identifiable {
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