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
    
    let appLaunch: AppLaunch
    let modelContext: ModelContext

    let keyManager: KeyManager
    let x3dh: X3DH
    let chatManager: ChatManager
    let messageService: MessageService
    let userService: UserService
    let registrationService: RegistrationService
    
    convenience init() {
        let modelContext = Self.createDefaultModelContext()
        self.init(modelContext: modelContext)
    }
    
    init(modelContext: ModelContext) {
        self.appLaunch = AppLaunch()
        self.modelContext = modelContext
        
        let restClient = try! RestClient(baseURLStr: "http://127.0.0.1:48080")
        
        // Initialize UserService (since it has @MainActor methods but is not fully isolated)
        let userRepository = SwiftDataUserRepository(modelContext: modelContext)
        let userService = UserService(userRepository: userRepository)
        self.userService = userService
        
        // Initialize crypto services
        self.keyManager = KeyManager()
        self.x3dh = X3DH(keyManager: keyManager)
        
        // Initialize chat services
        let chatRepository = SwiftDataChatRepository(modelContext: modelContext)
        self.chatManager = ChatManager(
            chatRepository: chatRepository,
            userService: userService,
            messageGateway: restClient,
            keyGateway: restClient,
            x3dh: x3dh
        )
        
        // Initialize messaging services
        self.messageService = MessageService(
            messageGateway: restClient,
            keyGateway: restClient,
            userService: userService,
            chatManager: chatManager
        )
        
        // Initialize registration services
        self.registrationService = RegistrationService(
            registrationGateway: restClient,
            keyManager: keyManager,
            keyGateway: restClient,
            userService: userService
        )
    }
    
    func onAppStart() async {
        appLaunch.setLoading()
        do {
            resetSwiftDataStoreIfNeeded()
            
            try await userService.populateSelectedUser()
            
            if userService.selectedUsername != nil {
                appLaunch.setRegistered()
            } else {
                appLaunch.setUnregistered()
            }
            
            print("APP LAUNCH IS NOW: \(appLaunch.state)")
        } catch {
            appLaunch.setError()
        }
    }
}

