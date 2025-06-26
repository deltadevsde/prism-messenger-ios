//
//  RealTimeCommunication.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

protocol RealTimeCommunication {
    func connect() async
    func disconnect()
}
