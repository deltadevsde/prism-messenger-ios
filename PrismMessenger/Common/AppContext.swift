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

    let chatService: ChatService
    let messageService: MessageService
    let userService: UserService
    let registrationService: RegistrationService

    required init(
        modelContext: ModelContext,
        chatService: ChatService,
        messageService: MessageService,
        userService: UserService,
        registrationService: RegistrationService
    ) {
        self.appLaunch = AppLaunch()
        self.modelContext = modelContext
        self.chatService = chatService
        self.messageService = messageService
        self.userService = userService
        self.registrationService = registrationService
    }

    static func forProd() -> Self {
        let modelContext = AppContext.createDefaultModelContext()

        let userRepository = SwiftDataUserRepository(modelContext: modelContext)
        let userService = UserService(userRepository: userRepository)

        let restClient = try! RestClient(baseURLStr: "http://127.0.0.1:48080", userService: userService)

        // Initialize crypto services
        let tee = SecurePersistentTee()
        let x3dh = X3DH(tee: tee)

        // Initialize chat services
        let chatRepository = SwiftDataChatRepository(modelContext: modelContext)
        let chatService = ChatService(
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
            chatService: chatService
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
            chatService: chatService,
            messageService: messageService,
            userService: userService,
            registrationService: registrationService)
    }

    static func forPreview() -> Self {
        let modelContext = AppContext.createInMemoryModelContext()

        let userRepository = SwiftDataUserRepository(modelContext: modelContext)
        let userService = UserService(userRepository: userRepository)

        let simulatedBackend = FakeClient(userService: userService)

        // Initialize crypto services
        let tee = InMemoryTee()
        let x3dh = X3DH(tee: tee)

        // Initialize chat services
        let chatRepository = SwiftDataChatRepository(modelContext: modelContext)
        let chatService = ChatService(
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
            chatService: chatService
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
            chatService: chatService,
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
