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
    let ownProfileService: OwnProfileService
    let otherProfileService: OtherProfileService
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
        ownProfileService: OwnProfileService,
        otherProfileService: OtherProfileService,
        pushNotificationCenter: PushNotificationCenter,
        pushNotificationDelegate: PushNotificationDelegate?,
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
        self.ownProfileService = ownProfileService
        self.otherProfileService = otherProfileService
        self.pushNotificationCenter = pushNotificationCenter
        self.pushNotificationDelegate = pushNotificationDelegate
        self.updatePushTokenService = updatePushTokenService
        self.userService = userService
        self.registrationService = registrationService
    }

    func connectAppDelegate(_ appDelegate: AppDelegate) {
        appDelegate.setServices(
            pushNotificationDelegate: pushNotificationDelegate, messageService: messageService)
    }
}
