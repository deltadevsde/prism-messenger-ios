//
//  AppContext.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation

class AppContext: ObservableObject {
    let signupService: RegistrationService
    let keyService: KeyService
    
    init() throws {
        let restClient = try RestClient(baseURLStr: "http://127.0.0.1:48080")
        let keyManager = KeyManager()
        signupService = RegistrationService(restClient: restClient, keyManager: keyManager)
        keyService = KeyService(restClient: restClient, keyManager: keyManager)
    }
}
