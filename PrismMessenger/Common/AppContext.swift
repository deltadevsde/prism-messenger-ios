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
    let connectionService: ConnectionService
    let presenceService: PresenceService
    let typingService: TypingService
    let ownProfileService: OwnProfileService
    let profileCacheService: ProfileCacheService
    let profilePictureCacheService: ProfilePictureCacheService
    let profilePictureCleanupService: ProfilePictureCleanupService
    let pushNotificationCenter: PushNotificationCenter
    let pushNotificationDelegate: PushNotificationDelegate?
    let updatePushTokenService: UpdatePushTokenService
    let userService: UserService
    let registrationService: RegistrationService

    init(
        modelContext: ModelContext,
        scenePhaseRepository: ScenePhaseRepository,
        router: NavigationRouter,
        chatService: ChatService,
        messageService: MessageService,
        messageNotificationService: MessageNotificationService,
        connectionService: ConnectionService,
        presenceService: PresenceService,
        typingService: TypingService,
        ownProfileService: OwnProfileService,
        profileCacheService: ProfileCacheService,
        profilePictureCacheService: ProfilePictureCacheService,
        profilePictureCleanupService: ProfilePictureCleanupService,
        pushNotificationCenter: PushNotificationCenter,
        pushNotificationDelegate: PushNotificationDelegate?,
        updatePushTokenService: UpdatePushTokenService,
        userService: UserService,
        registrationService: RegistrationService,
    ) {
        self.modelContext = modelContext
        self.scenePhaseRepository = scenePhaseRepository
        self.router = router
        self.chatService = chatService
        self.messageService = messageService
        self.messageNotificationService = messageNotificationService
        self.connectionService = connectionService
        self.presenceService = presenceService
        self.typingService = typingService
        self.ownProfileService = ownProfileService
        self.profileCacheService = profileCacheService
        self.profilePictureCacheService = profilePictureCacheService
        self.profilePictureCleanupService = profilePictureCleanupService
        self.pushNotificationCenter = pushNotificationCenter
        self.pushNotificationDelegate = pushNotificationDelegate
        self.updatePushTokenService = updatePushTokenService
        self.userService = userService
        self.registrationService = registrationService
    }

    func connectAppDelegate(_ appDelegate: AppDelegate) {
        appDelegate.setServices(
            pushNotificationDelegate: pushNotificationDelegate,
            messageService: messageService,
            connectionService: connectionService)
    }
}
