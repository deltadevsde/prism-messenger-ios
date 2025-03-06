//
//  AppContext.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation
import SwiftData

class AppContext: ObservableObject {
    // Services
    let keyManager: KeyManager
    let signupService: RegistrationService
    let keyService: KeyService
    let chatManager: ChatManager
    let messageService: MessageService
    let userManager: UserManager
    let messageCoordinator: MessageCoordinator
    let backendGateway: BackendGateway
    
    // Database
    let modelContext: ModelContext
    
    init(modelContext: ModelContext) throws {
        self.modelContext = modelContext
        
        // Create the RestClient and BackendGateway
        let restClient = try RestClient(baseURLStr: "http://127.0.0.1:48080")
        backendGateway = BackendGateway(restClient: restClient)
        
        // Create the services
        keyManager = KeyManager()
        userManager = UserManager(modelContext: modelContext)
        
        // Initialize services with gateways
        signupService = RegistrationService(
            restClient: restClient, 
            keyManager: keyManager
        )
        
        keyService = KeyService(
            restClient: restClient,
            keyManager: keyManager
        )
        
        chatManager = ChatManager(
            modelContext: modelContext,
            userManager: userManager
        )
        
        messageService = MessageService(
            restClient: restClient,
            modelContext: modelContext,
            userManager: userManager,
            keyService: keyService
        )
        
        // Initialize the message coordinator
        messageCoordinator = MessageCoordinator(
            messageService: messageService,
            chatManager: chatManager,
            userManager: userManager
        )
        
        // Pass necessary references after all initialization is complete
        messageService.appContext = self
    }
    
    func createX3DHSession() throws -> X3DH {
        return X3DH(keyManager: keyManager)
    }
}
