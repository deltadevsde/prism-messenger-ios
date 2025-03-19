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

    let modelContext: ModelContext
    let appLaunch: AppLaunch

    let chatManager: ChatManager
    let messageService: MessageService
    let userService: UserService
    let registrationService: RegistrationService

    required init(
        modelContext: ModelContext,
        chatManager: ChatManager,
        messageService: MessageService,
        userService: UserService,
        registrationService: RegistrationService
    ) {
        self.appLaunch = AppLaunch()
        self.modelContext = modelContext
        self.chatManager = chatManager
        self.messageService = messageService
        self.userService = userService
        self.registrationService = registrationService
    }

    static func forProd() -> Self {
        let modelContext = AppContext.createDefaultModelContext()
        let restClient = try! RestClient(baseURLStr: "http://127.0.0.1:48080")

        // Initialize UserService (since it has @MainActor methods but is not fully isolated)
        let userRepository = SwiftDataUserRepository(modelContext: modelContext)
        let userService = UserService(userRepository: userRepository)

        // Initialize crypto services
        let tee = SecurePersistentTee()
        let x3dh = X3DH(tee: tee)

        // Initialize chat services
        let chatRepository = SwiftDataChatRepository(modelContext: modelContext)
        let chatManager = ChatManager(
            chatRepository: chatRepository,
            userService: userService,
            messageGateway: restClient,
            keyGateway: restClient,
            x3dh: x3dh
        )

        // Initialize messaging services
        let messageService = MessageService(
            messageGateway: restClient,
            keyGateway: restClient,
            userService: userService,
            chatManager: chatManager
        )

        // Initialize registration services
        let registrationService = RegistrationService(
            registrationGateway: restClient,
            tee: tee,
            keyGateway: restClient,
            userService: userService
        )

        return Self(
            modelContext: modelContext,
            chatManager: chatManager,
            messageService: messageService,
            userService: userService,
            registrationService: registrationService)
    }

    static func forPreview() -> Self {
        let modelContext = AppContext.createInMemoryModelContext()
        let simulatedBackend = FakeClient()

        // Initialize UserService (since it has @MainActor methods but is not fully isolated)
        let userRepository = SwiftDataUserRepository(modelContext: modelContext)
        let userService = UserService(userRepository: userRepository)

        // Initialize crypto services
        let tee = InMemoryTee()
        let x3dh = X3DH(tee: tee)

        // Initialize chat services
        let chatRepository = SwiftDataChatRepository(modelContext: modelContext)
        let chatManager = ChatManager(
            chatRepository: chatRepository,
            userService: userService,
            messageGateway: simulatedBackend,
            keyGateway: simulatedBackend,
            x3dh: x3dh
        )

        // Initialize messaging services
        let messageService = MessageService(
            messageGateway: simulatedBackend,
            keyGateway: simulatedBackend,
            userService: userService,
            chatManager: chatManager
        )

        // Initialize registration services
        let registrationService = RegistrationService(
            registrationGateway: simulatedBackend,
            tee: tee,
            keyGateway: simulatedBackend,
            userService: userService
        )

        return Self(
            modelContext: modelContext,
            chatManager: chatManager,
            messageService: messageService,
            userService: userService,
            registrationService: registrationService)
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
