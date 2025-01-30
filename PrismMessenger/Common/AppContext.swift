//
//  AppContext.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation

class AppContext: ObservableObject {
    let signupService: RegistrationService
    
    init() throws {
        let restClient = try RestClient(baseURLStr: "http://127.0.0.1:48080")
        signupService = RegistrationService(restClient: restClient)
    }
}
