//
//  BuildSettings.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation

enum BuildSettings {
    static let serverURL: String = {
        print(Bundle.main.infoDictionary?.keys ?? [])
        guard let serverURL = Bundle.main.object(forInfoDictionaryKey: "SERVER_URL") as? String
        else {
            fatalError("SERVER_URL not found in Info.plist")
        }
        return serverURL
    }()

    static let webSocketURL: String = {
        guard
            let webSocketURL = Bundle.main.object(forInfoDictionaryKey: "WEBSOCKET_URL") as? String
        else {
            fatalError("WEBSOCKET_URL not found in Info.plist")
        }
        return webSocketURL
    }()
}
