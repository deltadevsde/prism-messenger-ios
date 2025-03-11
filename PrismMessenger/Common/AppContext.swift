//
//  AppContext.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation
import SwiftData

@MainActor
class AppContext: ObservableObject {
    // Make keyManager accessible since it's needed for X3DH processing
    let keyManager: KeyManager
    let backendGateway: BackendGatewayProtocol
    
    let chatRepository: ChatRepository
    let chatManager: ChatManager
    let modelContext: ModelContext
    let userService: UserService
    weak var appLaunch: AppLaunch?
    
    // Convenience properties for backward compatibility
    var signupService: RegistrationServiceProtocol { backendGateway.registrationService }
    var keyService: KeyServiceProtocol { backendGateway.keyService }
    var messageService: MessageServiceProtocol { backendGateway.messageService }
    
    init(modelContext: ModelContext) throws {
        self.modelContext = modelContext
        
        // Initialize UserService (since it has @MainActor methods but is not fully isolated)
        let userRepository = ModelContextUserRepository(modelContext: modelContext)
        let userService = UserService(userRepository: userRepository)
        self.userService = userService
        
        // Initialize KeyManager
        self.keyManager = KeyManager()
        
        // Create the BackendGateway
        let gateway = try BackendGateway(modelContext: modelContext, userService: userService)
        self.backendGateway = gateway
        
        // Initialize ChatManager
        self.chatRepository = ModelContextChatRepository(modelContext: modelContext)
        self.chatManager = ChatManager(
            chatRepository: chatRepository,
            userRepository: userRepository
        )
        
        // Set appLaunch property for ChatManager (will be updated after init)
        chatManager.appLaunch = appLaunch
        
        // Set circular references
        gateway.setAppContext(self)
    }
    
    // Update appLaunch reference
    func setAppLaunch(_ appLaunch: AppLaunch) {
        self.appLaunch = appLaunch
        chatManager.appLaunch = appLaunch
        
        // Update appLaunch in BackendGateway
        if let gateway = backendGateway as? BackendGateway {
            gateway.setAppLaunch(appLaunch)
        }
    }
    
    /// Creates a new X3DH session
    /// - Returns: A new X3DH object initialized with the KeyManager
    func createX3DHSession() throws -> X3DH {
        return X3DH(keyManager: keyManager)
    }
}
