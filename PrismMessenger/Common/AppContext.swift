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
    let scenePhaseRepository: ScenePhaseRepository

    var router: NavigationRouter

    let chatService: ChatService
    let messageService: MessageService
    let messageNotificationService: MessageNotificationService
    let pushNotificationService: PushNotificationService
    let updatePushTokenService: UpdatePushTokenService
    let userService: UserService
    let registrationService: RegistrationService

    required init(
        modelContext: ModelContext,
        scenePhaseRepository: ScenePhaseRepository,
        router: NavigationRouter,
        chatService: ChatService,
        messageService: MessageService,
        messageNotificationService: MessageNotificationService,
        pushNotificationService: PushNotificationService,
        updatePushTokenService: UpdatePushTokenService,
        userService: UserService,
        registrationService: RegistrationService
    ) {
        self.modelContext = modelContext
        self.scenePhaseRepository = scenePhaseRepository
        self.router = router
        self.chatService = chatService
        self.messageService = messageService
        self.messageNotificationService = messageNotificationService
        self.pushNotificationService = pushNotificationService
        self.updatePushTokenService = updatePushTokenService
        self.userService = userService
        self.registrationService = registrationService
    }

    static func forProd() -> Self {
        let modelContext = AppContext.createDefaultModelContext()
        let scenePhaseRepository = ScenePhaseRepository()

        let router = NavigationRouter()

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

        // Initialize notification services
        let notificationCenter = DefaultUserNotificationCenter()
        let pushNotificationService = PushNotificationService()

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
        let messageNotificationService = MessageNotificationService(
            router: router,
            scenePhaseRepository: scenePhaseRepository,
            notificationCenter: notificationCenter,
            chatRepository: chatRepository
        )
        notificationCenter.setResponseHandler(messageNotificationService, for: .message)

        let messageService = MessageService(
            messageGateway: restClient,
            keyGateway: restClient,
            userService: userService,
            chatService: chatService,
            messageNotificationService: messageNotificationService
        )

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
            scenePhaseRepository: scenePhaseRepository,
            router: router,
            chatService: chatService,
            messageService: messageService,
            messageNotificationService: messageNotificationService,
            pushNotificationService: pushNotificationService,
            updatePushTokenService: updatePushTokenService,
            userService: userService,
            registrationService: registrationService)
    }

    static func forPreview() -> Self {
        let modelContext = AppContext.createInMemoryModelContext()
        let scenePhaseRepository = ScenePhaseRepository()

        let router = NavigationRouter()

        let userRepository = SwiftDataUserRepository(modelContext: modelContext)
        let userService = UserService(userRepository: userRepository)

        let simulatedBackend = FakeClient(userService: userService)

        // Initialize notification services
        let notificationCenter = FakeUserNotificationCenter()
        let pushNotificationService = PushNotificationService()

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
        let messageNotificationService = MessageNotificationService(
            router: router,
            scenePhaseRepository: scenePhaseRepository,
            notificationCenter: notificationCenter,
            chatRepository: chatRepository
        )
        notificationCenter.setResponseHandler(messageNotificationService, for: .message)

        let messageService = MessageService(
            messageGateway: simulatedBackend,
            keyGateway: simulatedBackend,
            userService: userService,
            chatService: chatService,
            messageNotificationService: messageNotificationService
        )

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
            scenePhaseRepository: scenePhaseRepository,
            router: router,
            chatService: chatService,
            messageService: messageService,
            messageNotificationService: messageNotificationService,
            pushNotificationService: pushNotificationService,
            updatePushTokenService: updatePushTokenService,
            userService: userService,
            registrationService: registrationService)
    }

    func onAppStart() async {
        router.setLaunchState(.loading)
        do {
            resetSwiftDataStoreIfNeeded()

            try await userService.populateSelectedUser()

            if userService.selectedUsername != nil {
                router.setLaunchState(.registered)
                try await updatePushTokenService.updatePushToken()
            } else {
                router.setLaunchState(.unregistered)
            }

            print("LaunchState is: \(router.launchState)")
        } catch {
            router.setLaunchState(.error)
        }
    }
}
