//
//  BackendGateway.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation
import CryptoKit
import SwiftData

// MARK: - Message Service Protocol

protocol MessageServiceProtocol {
    func sendMessage(_ message: DoubleRatchetMessage, from sender: String, to recipient: String) async throws -> SendMessageResponse
    func getCurrentUsername() async throws -> String
    func fetchMessages(for username: String) async throws -> [APIMessage]
    func markMessagesAsDelivered(messageIds: [UUID], for username: String) async throws
    func processReceivedMessages(
        messages: [APIMessage],
        currentUser: String,
        chatManager: ChatManager
    ) async throws -> [UUID]
    func fetchAndProcessMessages() async throws -> Int
}

// MARK: - Key Service Protocol

protocol KeyServiceProtocol {
    func initializeKeyBundle(username: String) async throws -> (KeyBundle, UserData)
    func submitKeyBundle(username: String, keyBundle: KeyBundle) async throws
    func getKeyBundle(username: String) async throws -> KeyBundle?
}

// MARK: - Registration Service Protocol

protocol RegistrationServiceProtocol {
    func checkUsernameAvailability(_ username: String) async -> Bool
    func requestRegistration(username: String) async throws -> RegistrationChallenge
    func finalizeRegistration(username: String, challenge: RegistrationChallenge) async throws
    func register(username: String) async throws
}

// MARK: - Backend Gateway Interface

protocol BackendGatewayProtocol {
    var messageService: MessageServiceProtocol { get }
    var keyService: KeyServiceProtocol { get }
    var registrationService: RegistrationServiceProtocol { get }
}

// MARK: - Backend Gateway Implementation

class BackendGateway: BackendGatewayProtocol {
    private let restClient: RestClient
    private let keyManager: KeyManager
    private let modelContext: ModelContext
    
    let messageService: MessageServiceProtocol
    let keyService: KeyServiceProtocol
    let registrationService: RegistrationServiceProtocol
    
    weak var appLaunch: AppLaunch?
    weak var appContext: AppContext?
    
    init(modelContext: ModelContext, userManager: UserManager) throws {
        self.modelContext = modelContext
        
        // Initialize RestClient
        let restClient = try RestClient(baseURLStr: "http://127.0.0.1:48080")
        self.restClient = restClient
        
        // Initialize KeyManager
        self.keyManager = KeyManager()
        
        // Initialize services with their concrete implementations
        let messageService = MessageService(restClient: restClient, modelContext: modelContext, userManager: userManager)
        let keyService = KeyService(restClient: restClient, keyManager: keyManager)
        let registrationService = RegistrationService(restClient: restClient, keyManager: keyManager)
        
        self.messageService = messageService
        self.keyService = keyService
        self.registrationService = registrationService
        
        // Set appContext on MessageService implementation
        if let msgService = messageService as? MessageService {
            msgService.appContext = appContext
        }
    }
    
    func setAppLaunch(_ appLaunch: AppLaunch) {
        self.appLaunch = appLaunch
        
        if let msgService = messageService as? MessageService {
            msgService.appLaunch = appLaunch
        }
    }
    
    func setAppContext(_ appContext: AppContext) {
        self.appContext = appContext
        
        if let msgService = messageService as? MessageService {
            msgService.appContext = appContext
        }
    }
}