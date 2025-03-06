//
//  BackendGateway.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation
import CryptoKit

// Error types
enum MessageError: Error {
    case unauthorized
    case serverError
    case networkFailure(Int)
}

// Already defined in RegistrationService.swift

enum KeyError: Error {
    case networkFailure(Int)
    case userNotFound
}

// Protocol for message-related API calls
protocol MessageGateway {
    func fetchMessages(for username: String) async throws -> [APIMessage]
    func sendMessage(_ message: DoubleRatchetMessage, from: String, to: String) async throws -> SendMessageResponse
    func markMessagesAsDelivered(messageIds: [UUID], for username: String) async throws
}

// Protocol for registration-related API calls
protocol RegistrationGateway {
    func checkUsernameAvailability(_ username: String) async throws -> Bool
    func requestRegistration(username: String) async throws -> String
    func finalizeRegistration(username: String, challenge: String, signature: Data) async throws
}

// Protocol for key-related API calls
protocol KeyGateway {
    func submitKeyBundle(_ keyBundle: KeyBundle, for username: String) async throws
    func getKeyBundle(username: String) async throws -> KeyBundle
}

// API models defined in MessageService.swift

// Registration request/response models
struct RegisterRequest: Encodable {
    var username: String
    var key: CryptoPayload
}

struct ChallengeResponse: Decodable {
    var challenge: String
}

struct FinalizeRequest: Encodable {
    var username: String
    var challenge: String
    var signature: Data
}

struct UploadKeyBundleRequest: Encodable {
    var user_id: String
    var keybundle: KeyBundle
}

struct KeyBundleResponse: Codable {
    var key_bundle: KeyBundle?
}

// Implementation that wraps RestClient
class BackendGateway: MessageGateway, RegistrationGateway, KeyGateway {
    private let restClient: RestClient
    
    init(restClient: RestClient) {
        self.restClient = restClient
    }
    
    // MARK: - MessageGateway implementation
    
    func fetchMessages(for username: String) async throws -> [APIMessage] {
        do {
            let messages: [APIMessage] = try await restClient.fetch(from: "/messages/get/\(username)")
            return messages
        } catch RestClientError.httpError(let statusCode) {
            switch statusCode {
            case 401:
                throw MessageError.unauthorized
            case 404:
                // No messages available is not an error
                return []
            case 500...599:
                throw MessageError.serverError
            default:
                throw MessageError.networkFailure(statusCode)
            }
        }
    }
    
    func sendMessage(_ message: DoubleRatchetMessage, from sender: String, to recipient: String) async throws -> SendMessageResponse {
        let request = SendMessageRequest(
            sender_id: sender, 
            recipient_id: recipient,
            message: message
        )
        
        do {
            return try await restClient.post(request, to: "/messages/send")
        } catch RestClientError.httpError(let statusCode) {
            switch statusCode {
            case 401:
                throw MessageError.unauthorized
            case 500...599:
                throw MessageError.serverError
            default:
                throw MessageError.networkFailure(statusCode)
            }
        }
    }
    
    func markMessagesAsDelivered(messageIds: [UUID], for username: String) async throws {
        let request = MarkDeliveredRequest(
            user_id: username,
            message_ids: messageIds
        )
        
        do {
            try await restClient.post(request, to: "/messages/mark-delivered")
        } catch RestClientError.httpError(let statusCode) {
            switch statusCode {
            case 401:
                throw MessageError.unauthorized
            case 500...599:
                throw MessageError.serverError
            default:
                throw MessageError.networkFailure(statusCode)
            }
        }
    }
    
    // MARK: - RegistrationGateway implementation
    
    func checkUsernameAvailability(_ username: String) async throws -> Bool {
        do {
            let response = try await restClient.getResponse(from: "/users/check/\(username)")
            // If username not found, it is available
            return response.statusCode == 404
        } catch {
            // For other errors, assume username is taken to be safe
            return false
        }
    }
    
    func requestRegistration(username: String) async throws -> String {
        let request = RegisterRequest(
            username: username,
            key: CryptoPayload(algorithm: .secp256r1, bytes: Data())
        )
        
        do {
            let response: ChallengeResponse = try await restClient.post(request, to: "/register/request")
            return response.challenge
        } catch RestClientError.httpError(let statusCode) {
            throw RegistrationError.networkFailure(statusCode)
        }
    }
    
    func finalizeRegistration(username: String, challenge: String, signature: Data) async throws {
        let request = FinalizeRequest(
            username: username,
            challenge: challenge,
            signature: signature
        )
        
        do {
            try await restClient.post(request, to: "/register/finalize")
        } catch RestClientError.httpError(let statusCode) {
            throw RegistrationError.networkFailure(statusCode)
        }
    }
    
    // MARK: - KeyGateway implementation
    
    func submitKeyBundle(_ keyBundle: KeyBundle, for username: String) async throws {
        let uploadRequest = UploadKeyBundleRequest(
            user_id: username,
            keybundle: keyBundle
        )
        
        do {
            try await restClient.post(uploadRequest, to: "/keys/upload")
        } catch RestClientError.httpError(let httpStatusCode) {
            throw KeyError.networkFailure(httpStatusCode)
        }
    }
    
    func getKeyBundle(username: String) async throws -> KeyBundle {
        do {
            let response: KeyBundleResponse = try await restClient.fetch(from: "/keys/bundle/\(username)")
            guard let keyBundle = response.key_bundle else {
                throw KeyError.userNotFound
            }
            return keyBundle
        } catch RestClientError.httpError(let httpStatusCode) {
            if httpStatusCode == 404 {
                throw KeyError.userNotFound
            }
            throw KeyError.networkFailure(httpStatusCode)
        }
    }
}