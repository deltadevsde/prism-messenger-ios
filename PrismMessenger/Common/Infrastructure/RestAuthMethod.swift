//
//  RestAuthMethod.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation

enum RestAuthMethod {
    case none
    case basic(username: String, password: String)
}


extension URLRequest {
    mutating func applyAuth(_ authMethod: RestAuthMethod) throws {
        switch authMethod {
            case .none:
                break  // No authentication needed
            case .basic(let username, let password):
                let authString = "\(username):\(password)"
                guard let authData = authString.data(using: .utf8) else {
                    throw EncodingError
                        .invalidValue(
                            authString,
                            EncodingError.Context(codingPath: [], debugDescription: "")
                        )
                }
                let base64Auth = authData.base64EncodedString()
                setValue("Basic \(base64Auth)", forHTTPHeaderField: "Authorization")
        }
    }
}