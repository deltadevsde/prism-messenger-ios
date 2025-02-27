//
//  AppContext.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation
import SwiftData

class AppContext: ObservableObject {
    private let keyManager: KeyManager
    let signupService: RegistrationService
    let keyService: KeyService
    let chatManager: ChatManager
    
    init(modelContext: ModelContext) throws {
        let restClient = try RestClient(baseURLStr: "http://127.0.0.1:48080")
        keyManager = KeyManager()
        signupService = RegistrationService(restClient: restClient, keyManager: keyManager)
        keyService = KeyService(restClient: restClient, keyManager: keyManager)
        chatManager = ChatManager(modelContext: modelContext)
    }
    
    func createX3DHSession() throws -> X3DH {
        return X3DH(keyManager: keyManager)
    }
}
