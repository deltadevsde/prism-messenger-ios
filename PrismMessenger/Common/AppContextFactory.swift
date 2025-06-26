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
            let webSocketUrl = "ws://127.0.0.1:48080"
        #else
            let serverUrl = BuildSettings.serverURL
            let webSocketUrl = BuildSettings.webSocketURL
        #endif

        let restClient = try! RestClient(
            baseURLStr: serverUrl,
            userService: userService
        )

        let webSocketClient = try! WebSocketClient(
            baseURLStr: webSocketUrl,
            userService: userService
        )

        // Initialize notification services
        let notificationCenter = DefaultUserNotificationCenter()
        let pushNotificationCenter = DefaultPushNotificationCenter()

        // Initialize profile services
        let profileRepository = SwiftDataProfileRepository(modelContext: modelContext)
        let profilePictureRepository = SwiftDataProfilePictureRepository(modelContext: modelContext)
        let profilePictureCacheService = ProfilePictureCacheService(
            profilePictureRepository: profilePictureRepository,
            profilePictureGateway: restClient
        )
        let profileCacheService = ProfileCacheService(
            profileRepository: profileRepository,
            profileGateway: restClient,
            profilePictureCacheService: profilePictureCacheService
        )
        let ownProfileService = OwnProfileService(
            profileGateway: restClient,
            profilePictureGateway: restClient,
            profileCacheService: profileCacheService,
            profilePictureCacheService: profilePictureCacheService,
            userService: userService
        )
        let profilePictureCleanupService = ProfilePictureCleanupService(
            profileRepository: profileRepository,
            profilePictureRepository: profilePictureRepository
        )

        // Initialize crypto services
        let tee = SecurePersistentTee()
        let x3dh = X3DH(tee: tee)

        // Initialize chat services
        let chatRepository = SwiftDataChatRepository(modelContext: modelContext)
        let chatService = ChatService(
            chatRepository: chatRepository,
            userService: userService,
            profileCacheService: profileCacheService,
            messageSenderGateway: restClient,
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
            messageSenderGateway: restClient,
            messageReceiverGateway: webSocketClient,
            keyGateway: restClient,
            userService: userService,
            chatService: chatService,
            messageNotificationService: messageNotificationService
        )

        // Initialize connection service
        let connectionService = ConnectionService(
            realTimeCommunication: webSocketClient,
            scenePhaseRepository: scenePhaseRepository
        )

        // Initialize presence service
        let presenceService = PresenceService(
            presenceFetchGateway: restClient,
            presenceRtcGateway: webSocketClient
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
            connectionService: connectionService,
            presenceService: presenceService,
            ownProfileService: ownProfileService,
            profileCacheService: profileCacheService,
            profilePictureCacheService: profilePictureCacheService,
            profilePictureCleanupService: profilePictureCleanupService,
            pushNotificationCenter: pushNotificationCenter,
            pushNotificationDelegate: pushNotificationCenter,
            updatePushTokenService: updatePushTokenService,
            userService: userService,
            registrationService: registrationService
        )
    }

    static func forTest(storeProvider: InMemoryStoreProvider = InMemoryStoreProvider())
        -> AppContext
    {
        let modelContext = ModelContextProvider.createInMemoryModelContext()
        let scenePhaseRepository = ScenePhaseRepository()

        let router = NavigationRouter()

        let userRepository = SwiftDataUserRepository(modelContext: modelContext)
        let userService = UserService(userRepository: userRepository)

        let simulatedBackend = FakeClient(storeProvider: storeProvider, userService: userService)

        // Initialize notification services
        let notificationCenter = FakeUserNotificationCenter()
        let pushNotificationCenter = FakePushNotificationCenter()

        // Initialize profile services
        let profileRepository = SwiftDataProfileRepository(modelContext: modelContext)
        let profilePictureRepository = SwiftDataProfilePictureRepository(modelContext: modelContext)
        let profilePictureCacheService = ProfilePictureCacheService(
            profilePictureRepository: profilePictureRepository,
            profilePictureGateway: simulatedBackend
        )
        let profileCacheService = ProfileCacheService(
            profileRepository: profileRepository,
            profileGateway: simulatedBackend,
            profilePictureCacheService: profilePictureCacheService
        )
        let ownProfileService = OwnProfileService(
            profileGateway: simulatedBackend,
            profilePictureGateway: simulatedBackend,
            profileCacheService: profileCacheService,
            profilePictureCacheService: profilePictureCacheService,
            userService: userService
        )
        let profilePictureCleanupService = ProfilePictureCleanupService(
            profileRepository: profileRepository,
            profilePictureRepository: profilePictureRepository
        )

        // Initialize crypto services
        let tee = InMemoryTee()
        let x3dh = X3DH(tee: tee)

        // Initialize chat services
        let chatRepository = SwiftDataChatRepository(modelContext: modelContext)
        let chatService = ChatService(
            chatRepository: chatRepository,
            userService: userService,
            profileCacheService: profileCacheService,
            messageSenderGateway: simulatedBackend,
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
            messageSenderGateway: simulatedBackend,
            messageReceiverGateway: simulatedBackend,
            keyGateway: simulatedBackend,
            userService: userService,
            chatService: chatService,
            messageNotificationService: messageNotificationService
        )

        // Initialize connection service for testing
        let connectionService = ConnectionService(
            realTimeCommunication: simulatedBackend,
            scenePhaseRepository: scenePhaseRepository
        )

        // Initialize presence services
        let presenceService = PresenceService(
            presenceFetchGateway: simulatedBackend,
            presenceRtcGateway: simulatedBackend
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
            connectionService: connectionService,
            presenceService: presenceService,
            ownProfileService: ownProfileService,
            profileCacheService: profileCacheService,
            profilePictureCacheService: profilePictureCacheService,
            profilePictureCleanupService: profilePictureCleanupService,
            pushNotificationCenter: pushNotificationCenter,
            pushNotificationDelegate: nil,
            updatePushTokenService: updatePushTokenService,
            userService: userService,
            registrationService: registrationService
        )
    }

    static func twoForTest() -> (AppContext, AppContext) {
        let storeProvider = InMemoryStoreProvider()
        return (
            forTest(storeProvider: storeProvider), forTest(storeProvider: storeProvider)
        )
    }
}
