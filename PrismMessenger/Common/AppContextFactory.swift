//
//  AppContextFactory.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation
import SwiftData

@MainActor
class AppContextFactory {

    static func forProd() -> AppContext {
        let modelContext = ModelContextProvider.createDefaultModelContext()
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
        let pushNotificationCenter = DefaultPushNotificationCenter()

        // Initialize profile services
        let profileRepository = SwiftDataProfileRepository(modelContext: modelContext)
        let profileService = ProfileService(
            profileRepository: profileRepository,
            profileGateway: restClient,
            profilePictureGateway: restClient,
            userService: userService,
        )

        // Initialize crypto services
        let tee = SecurePersistentTee()
        let x3dh = X3DH(tee: tee)

        // Initialize chat services
        let chatRepository = SwiftDataChatRepository(modelContext: modelContext)
        let chatService = ChatService(
            chatRepository: chatRepository,
            userService: userService,
            profileService: profileService,
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
            pushNotificationCenter: pushNotificationCenter,
            userService: userService
        )

        // Initialize remaining account services
        let updatePushTokenService = UpdatePushTokenService(
            userService: userService,
            userGateway: restClient,
            pushNotificationService: pushNotificationCenter
        )

        return AppContext(
            modelContext: modelContext,
            scenePhaseRepository: scenePhaseRepository,
            router: router,
            chatService: chatService,
            messageService: messageService,
            messageNotificationService: messageNotificationService,
            profileService: profileService,
            pushNotificationCenter: pushNotificationCenter,
            pushNotificationDelegate: pushNotificationCenter,
            updatePushTokenService: updatePushTokenService,
            userService: userService,
            registrationService: registrationService
        )
    }

    static func forTest(
        withSimulatedBackendStore simulatedBackendStore: InMemoryStore = InMemoryStore()
    )
        -> AppContext
    {
        let modelContext = ModelContextProvider.createInMemoryModelContext()
        let scenePhaseRepository = ScenePhaseRepository()

        let router = NavigationRouter()

        let userRepository = SwiftDataUserRepository(modelContext: modelContext)
        let userService = UserService(userRepository: userRepository)

        let simulatedBackend = FakeClient(store: simulatedBackendStore, userService: userService)

        // Initialize notification services
        let notificationCenter = FakeUserNotificationCenter()
        let pushNotificationCenter = FakePushNotificationCenter()

        // Initialize profile services
        let profileRepository = SwiftDataProfileRepository(modelContext: modelContext)
        let profileService = ProfileService(
            profileRepository: profileRepository,
            profileGateway: simulatedBackend,
            profilePictureGateway: simulatedBackend,
            userService: userService,
        )

        // Initialize crypto services
        let tee = InMemoryTee()
        let x3dh = X3DH(tee: tee)

        // Initialize chat services
        let chatRepository = SwiftDataChatRepository(modelContext: modelContext)
        let chatService = ChatService(
            chatRepository: chatRepository,
            userService: userService,
            profileService: profileService,
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
            pushNotificationCenter: pushNotificationCenter,
            userService: userService
        )

        // Initialize remaining account services
        let updatePushTokenService = UpdatePushTokenService(
            userService: userService,
            userGateway: simulatedBackend,
            pushNotificationService: pushNotificationCenter
        )

        return AppContext(
            modelContext: modelContext,
            scenePhaseRepository: scenePhaseRepository,
            router: router,
            chatService: chatService,
            messageService: messageService,
            messageNotificationService: messageNotificationService,
            profileService: profileService,
            pushNotificationCenter: pushNotificationCenter,
            pushNotificationDelegate: nil,
            updatePushTokenService: updatePushTokenService,
            userService: userService,
            registrationService: registrationService
        )
    }

    static func twoForTest() -> (AppContext, AppContext) {
        let store = InMemoryStore()
        return (
            forTest(withSimulatedBackendStore: store), forTest(withSimulatedBackendStore: store)
        )
    }
}
