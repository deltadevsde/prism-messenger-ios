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
    let pushNotificationService: PushNotificationService
    let updatePushTokenService: UpdatePushTokenService
    let userService: UserService
    let registrationService: RegistrationService

    required init(
        modelContext: ModelContext,
        chatService: ChatService,
        messageService: MessageService,
        pushNotificationService: PushNotificationService,
        updatePushTokenService: UpdatePushTokenService,
        userService: UserService,
        registrationService: RegistrationService
    ) {
        self.appLaunch = AppLaunch()
        self.modelContext = modelContext
        self.chatService = chatService
        self.messageService = messageService
        self.pushNotificationService = pushNotificationService
        self.updatePushTokenService = updatePushTokenService
        self.userService = userService
        self.registrationService = registrationService
    }

    static func forProd() -> Self {
        let modelContext = AppContext.createDefaultModelContext()

        let userRepository = SwiftDataUserRepository(modelContext: modelContext)
        let userService = UserService(userRepository: userRepository)

        #if targetEnvironment(simulator)
            let serverUrl = "http://127.0.0.1:48080"
        #else
            let serverUrl = BuildSettings.serverURL
        #endif

        let restClient = try! RestClient(
            baseURLStr: serverUrl,
            userService: userService
        )

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

        // Initialize notification services
        let pushNotificationService = PushNotificationService()

        // Initialize registration services
        let registrationService = RegistrationService(
            registrationGateway: restClient,
            tee: tee,
            keyGateway: restClient,
            pushNotificationService: pushNotificationService,
            userService: userService
        )

        // Initialize remaining account services
        let updatePushTokenService = UpdatePushTokenService(
            userService: userService,
            userGateway: restClient,
            pushNotificationService: pushNotificationService
        )

        return Self(
            modelContext: modelContext,
            chatService: chatService,
            messageService: messageService,
            pushNotificationService: pushNotificationService,
            updatePushTokenService: updatePushTokenService,
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

        // Initialize notification services
        let pushNotificationService = PushNotificationService()

        // Initialize registration services
        let registrationService = RegistrationService(
            registrationGateway: simulatedBackend,
            tee: tee,
            keyGateway: simulatedBackend,
            pushNotificationService: pushNotificationService,
            userService: userService
        )

        // Initialize remaining account services
        let updatePushTokenService = UpdatePushTokenService(
            userService: userService,
            userGateway: simulatedBackend,
            pushNotificationService: pushNotificationService
        )

        return Self(
            modelContext: modelContext,
            chatService: chatService,
            messageService: messageService,
            pushNotificationService: pushNotificationService,
            updatePushTokenService: updatePushTokenService,
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
                try await updatePushTokenService.updatePushToken()
            } else {
                appLaunch.setUnregistered()
            }

            print("APP LAUNCH IS NOW: \(appLaunch.state)")
        } catch {
            appLaunch.setError()
        }
    }
}
