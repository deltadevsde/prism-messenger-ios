//
//  ChatService.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import CryptoKit
import Foundation
import SwiftData

private let log = Log.messages

enum ChatServiceError: Error {
    case noCurrentUser
    case otherUserNotFound
    case keyExchangeFailed
    case missingKeyBundle
    case missingPreKeys
    case networkFailure(Int)
    case databaseFailure
    case decodingMessageFailed
}

@MainActor
class ChatService: ObservableObject {
    private let chatRepository: ChatRepository
    private let userService: UserService
    private let profileCacheService: ProfileCacheService
    private let messageSenderGateway: MessageSenderGateway
    private let keyGateway: KeyGateway
    private let x3dh: X3DH

    init(
        chatRepository: ChatRepository,
        userService: UserService,
        profileCacheService: ProfileCacheService,
        messageSenderGateway: MessageSenderGateway,
        keyGateway: KeyGateway,
        x3dh: X3DH
    ) {
        self.chatRepository = chatRepository
        self.userService = userService
        self.profileCacheService = profileCacheService
        self.messageSenderGateway = messageSenderGateway
        self.keyGateway = keyGateway
        self.x3dh = x3dh
    }

    func startChat(with otherUsername: String) async throws -> Chat {
        do {
            // Check if there's a profile for this username
            guard
                let profile = try await profileCacheService.fetchProfile(
                    byUsername: otherUsername)
            else {
                throw ChatServiceError.otherUserNotFound
            }

            // If a chat with this user already exists, reuse it
            if let existingChat = try await getChat(with: profile.accountId) {
                return existingChat
            }

            // Try to get the key bundle from the other user
            guard
                let keyBundle = try await keyGateway.fetchKeyBundle(for: profile.accountId)
            else {
                throw ChatServiceError.missingKeyBundle
            }

            guard let prekey = keyBundle.prekeys.first else {
                throw ChatServiceError.missingPreKeys
            }

            // Perform the X3DH handshake
            let (sharedSecret, ephemeralPrivateKey, usedPrekeyId) = try x3dh.initiateHandshake(
                with: keyBundle,
                using: prekey.keyIdx
            )

            log.debug(
                "Successfully performed X3DH handshake with: \(profile.username)"
            )
            log.debug("Used prekey ID: \(String(describing: usedPrekeyId))")

            // Create a new chat with the Double Ratchet session
            return try await createChat(
                with: profile,
                sharedSecret: sharedSecret,
                ephemeralPrivateKey: ephemeralPrivateKey,
                prekey: prekey
            )

        } catch KeyGatewayError.requestFailed(let statusCode) {
            throw ChatServiceError.networkFailure(statusCode)
        } catch KeyGatewayError.userNotFound {
            throw ChatServiceError.otherUserNotFound
        } catch is X3DHError {
            throw ChatServiceError.keyExchangeFailed
        }
    }

    /// Creates a new chat from an X3DH handshake and stores it in the repository
    /// - Parameters:
    ///   - otherId: The participant's ID
    ///   - sharedSecret: The shared secret derived from X3DH
    ///   - ephemeralPublicKey: The ephemeral public key used in X3DH
    ///   - prekey: The prekey that was used
    /// - Returns: The created Chat object
    func createChat(
        with profile: Profile,
        sharedSecret: SymmetricKey,
        ephemeralPrivateKey: P256.KeyAgreement.PrivateKey,
        prekey: Prekey
    ) async throws -> Chat {

        // 1. Create a Double Ratchet session with the shared secret
        let session = try createDoubleRatchetSession(
            sharedSecret: sharedSecret,
            localEphemeral: ephemeralPrivateKey,
            remoteEphemeral: prekey.key,
            prekeyID: prekey.keyIdx
        )

        // 2. Serialize the session
        let sessionData = try serializeDoubleRatchetSession(session)
        let jsonStr = String(data: sessionData, encoding: .utf8)!
        log.debug("sessionData from sender: \(jsonStr)")

        // 3. Create and save the chat
        let chat = Chat(
            participantId: profile.accountId,
            displayName: profile.username,
            doubleRatchetSession: sessionData
        )

        try await chatRepository.saveChat(chat)

        return chat
    }

    /// Retrieves a chat with a specific participant for the current user, if it exists
    /// - Parameter participantId: The participant's id
    /// - Returns: The Chat object if found, nil otherwise
    func getChat(with participantId: UUID) async throws -> Chat? {
        do {
            return try await chatRepository.getChat(
                withParticipant: participantId,
            )
        } catch {
            throw ChatServiceError.databaseFailure
        }
    }

    func getAllChats() async throws -> [Chat] {
        return try await chatRepository.getAllChats()
    }

    /// Creates a DoubleRatchetSession from the shared secret from X3DH
    private func createDoubleRatchetSession(
        sharedSecret: SymmetricKey,
        localEphemeral: P256.KeyAgreement.PrivateKey?,
        remoteEphemeral: P256.KeyAgreement.PublicKey?,
        prekeyID: UInt64?
    ) throws -> DoubleRatchetSession {
        // Convert SymmetricKey to Data
        let rootKeyData = sharedSecret.withUnsafeBytes { Data($0) }

        // Initialize the Double Ratchet session
        return DoubleRatchetSession(
            initialRootKey: rootKeyData,
            localEphemeral: localEphemeral,
            remoteEphemeral: remoteEphemeral,
            prekeyID: prekeyID
        )
    }

    /// Serializes a DoubleRatchetSession to Data
    private func serializeDoubleRatchetSession(_ session: DoubleRatchetSession) throws -> Data {
        let encoder = JSONEncoder()
        return try encoder.encode(session)
    }

    /// Deserializes Data back to a DoubleRatchetSession
    private func deserializeDoubleRatchetSession(from data: Data) throws -> DoubleRatchetSession {
        let decoder = JSONDecoder()
        return try decoder.decode(DoubleRatchetSession.self, from: data)
    }

    /// Creates a new chat from an incoming message using X3DH passive mode
    /// - Parameters:
    ///   - senderId: The ID of the message sender
    ///   - senderIdentityKey: The sender's identity key from their KeyBundle
    ///   - senderEphemeralKey: The sender's ephemeral key from the message header
    ///   - usedPrekeyId: The ID of our prekey that was used (if any)
    /// - Returns: The newly created Chat
    func createChatFromIncomingMessage(
        senderId: UUID,
        senderIdentityKey: P256.KeyAgreement.PublicKey,
        senderEphemeralKey: P256.KeyAgreement.PublicKey,
        usedPrekeyId: UInt64?
    ) async throws -> Chat {
        // 1. Get the current user's data
        guard let user = userService.currentUser else {
            throw ChatServiceError.noCurrentUser
        }

        // 2. Get the one-time prekey if it was used
        var receiverPrekey: P256.KeyAgreement.PrivateKey?

        if let prekeyId = usedPrekeyId, let prekey = user.getPrekey(keyIdx: prekeyId) {
            log.debug("USING PREKEY")
            receiverPrekey = prekey

            // Mark the prekey as used
            user.deletePrekey(keyIdx: prekeyId)
            try await userService.saveUser(user)
        }

        // 3. Compute the X3DH shared secret (from receiver's perspective)
        let symmetricKey = try x3dh.performPassiveX3DH(
            senderEphemeralKey: senderEphemeralKey,
            senderIdentityKey: senderIdentityKey,
            receiverSignedPreKey: user.signedPrekey,
            receiverOneTimePreKey: receiverPrekey
        )

        // 4. Create a Double Ratchet session with the shared secret
        let session = try createDoubleRatchetSession(
            sharedSecret: symmetricKey,
            localEphemeral: receiverPrekey,
            remoteEphemeral: senderEphemeralKey,
            prekeyID: nil
        )

        // 5. Serialize the session
        let sessionData = try serializeDoubleRatchetSession(session)
        let jsonStr = String(data: sessionData, encoding: .utf8)!
        log.debug("sessionData from recv: \(jsonStr)")

        // 6. Query the senders profile to populate the chat
        let profile = try? await profileCacheService.refreshProfile(byAccountId: senderId)

        // 7. Create and save the chat
        let chat = Chat(
            participantId: senderId,
            displayName: profile?.username ?? senderId.uuidString,
            doubleRatchetSession: sessionData
        )

        try await chatRepository.saveChat(chat)

        return chat
    }

    /// Sends a message in a chat
    /// - Parameters:
    ///   - content: The message content
    ///   - chat: The chat to send the message in
    /// - Returns: The created Message object
    func sendMessage(
        content: String,
        in chat: Chat
    ) async throws -> Message {
        // 1. Deserialize the Double Ratchet session
        let session = try deserializeDoubleRatchetSession(from: chat.doubleRatchetSession)

        // 2. Encrypt the message content
        let contentData = Data(content.utf8)
        let encryptedMessage = try session.encrypt(plaintext: contentData)

        // 3. Create the message with initial status of sending
        let message = Message(
            content: content,
            isFromMe: true,
            status: .sending
        )
        message.chat = chat
        chat.addMessage(message)

        // 4. Re-serialize the updated session state after encryption
        chat.doubleRatchetSession = try serializeDoubleRatchetSession(session)

        // Save initial state with "sending" status
        try await chatRepository.saveChat(chat)

        // 5. Send the encrypted message to the server
        do {
            // Send message to server using the MessageGateway
            let response = try await messageSenderGateway.sendMessage(
                encryptedMessage,
                to: chat.participantId
            )

            // Update message status to "sent" after server confirms receipt
            message.status = .sent
            message.serverId = response.messageId
            message.serverTimestamp = Date(
                timeIntervalSince1970: TimeInterval(response.timestamp) / 1000
            )

            try await chatRepository.saveChat(chat)
        } catch {
            // If sending fails, mark message as failed
            message.status = .failed
            try await chatRepository.saveChat(chat)
            throw error
        }

        return message
    }

    /// Receive and process an incoming message
    /// - Parameters:
    ///   - drMessage: The encrypted DoubleRatchetMessage
    ///   - chat: The chat this message belongs to
    ///   - sender: The sender's username
    /// - Returns: The created Message object if successful
    func receiveMessage(
        _ receivedMessage: ReceivedMessage,
        in chat: Chat,
    ) async throws -> Message? {
        log.debug("Receiving message in chat with \(receivedMessage.senderId)")
        do {
            // 1. Deserialize the Double Ratchet session
            log.debug(
                "Deserializing Double Ratchet session from \(chat.doubleRatchetSession.count) bytes"
            )
            let session = try deserializeDoubleRatchetSession(from: chat.doubleRatchetSession)
            log.debug("Successfully deserialized session")

            // 2. Decrypt the message content
            log.debug("About to decrypt message")
            log.debug("Ciphertext size: \(receivedMessage.message.ciphertext.count) bytes")
            log.debug("Nonce size: \(Data(receivedMessage.message.nonce).count) bytes")

            // Try multiple decryption approaches due to potential format issues
            let decryptedData: Data

            do {
                // Method 1: Use decrypt function with message
                decryptedData = try session.decrypt(message: receivedMessage.message)
                log.debug("Successfully decrypted message using method 1")
            } catch let error1 {
                log.debug("Method 1 failed: \(error1)")
                throw error1
            }

            // 3. Convert decrypted data to a string
            guard let content = String(data: decryptedData, encoding: .utf8) else {
                log.debug("Failed to decode string from data")
                throw ChatServiceError.decodingMessageFailed
            }
            log.debug("Decoded message: \(content)")

            // 4. Re-serialize the updated session state after decryption
            do {
                chat.doubleRatchetSession = try serializeDoubleRatchetSession(session)
                log.debug("Re-serialized session")
            } catch {
                log.debug("Failed to re-serialize session: \(error)")
                throw error
            }

            // 5. Create and save the message
            let message = Message(
                content: content,
                isFromMe: false,
                serverId: receivedMessage.messageId,
                serverTimestamp: Date(
                    timeIntervalSince1970: TimeInterval(receivedMessage.timestamp) / 1000
                ),
                status: .delivered,
            )
            message.chat = chat
            chat.addMessage(message)

            do {
                try await chatRepository.saveChat(chat)
                log.debug("Saved message to database")
            } catch {
                log.debug("Failed to save message: \(error)")
                throw error
            }

            return message
        } catch {
            log.debug("Error in receiveMessage: \(error)")
            throw error
        }
    }
}
