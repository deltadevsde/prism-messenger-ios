//
//  WebSocketClient.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation
import SwiftUI

private let log = Log.common

enum WebSocketError: Error {
    case invalidURL
    case connectionFailed
    case authenticationRequired
    case messageEncodingFailed
    case messageDecodingFailed
    case connectionClosed
    case unknown(Error)
}

protocol WebSocketMessage: Codable {
    var type: String { get }
}

private struct TypeEnvelope: Codable {
    let type: String
}

class WebSocketClient {
    private var webSocketTask: URLSessionWebSocketTask?
    private let baseURL: URL
    private let userService: UserService

    private var isConnecting = false
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = UInt64.max
    private let baseReconnectDelay: TimeInterval = 1.0
    private let maxReconnectDelay: TimeInterval = 30.0
    private var reconnectTask: Task<Void, Never>?

    private lazy var encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        // Configure encoder if needed
        return encoder
    }()

    private lazy var decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        // Configure decoder if needed
        return decoder
    }()

    private var messageHandlers: [String: (Data) async throws -> Void] = [:]

    init(baseURLStr: String = "ws://127.0.0.1:8080", userService: UserService) throws {
        guard let baseURL = URL(string: baseURLStr) else {
            throw WebSocketError.invalidURL
        }

        self.baseURL = baseURL
        self.userService = userService
    }

    func setMessageHandler<T: WebSocketMessage>(
        for type: String,
        handler: @escaping (T) async throws -> Void
    ) {
        messageHandlers[type] = { (data: Data) in
            do {
                let message = try self.decoder.decode(T.self, from: data)
                try await handler(message)
            } catch {
                log.error("Failed to decode message of type \(type): \(error)")
            }
        }
    }

    @MainActor
    private func authForCurrentUser() async throws -> RestAuthMethod {
        guard let user = userService.currentUser else {
            throw RestClientError.authenticationRequired
        }

        return .basic(username: user.id.uuidString, password: user.authPassword)
    }

    private func performConnect() async {
        guard !isConnecting else {
            log.debug("WebSocket connection already in progress, skipping connect")
            return
        }

        guard webSocketTask == nil else {
            log.debug("WebSocket connection already exists, skipping connect")
            return
        }

        isConnecting = true

        do {
            let authMethod = try await authForCurrentUser()
            let wsURL = baseURL.appendingPathComponent("ws")

            var request = URLRequest(url: wsURL)
            try request.applyAuth(authMethod)

            log.debug("Connecting to WebSocket: \(wsURL) (attempt \(self.reconnectAttempts + 1))")

            webSocketTask = URLSession.shared.webSocketTask(with: request)
            webSocketTask?.resume()

            reconnectAttempts = 0  // Reset on successful connection setup
            isConnecting = false

            await startListening()
        } catch {
            isConnecting = false
            log.error("Failed to connect to WebSocket: \(error)")
            scheduleReconnect()
        }
    }

    func sendMessage(_ message: any WebSocketMessage) async throws {
        guard let webSocketTask = webSocketTask else {
            log.warning("WebSocket not connected, cannot send message")
            return
        }

        do {
            let data = try encoder.encode(message)
            let message = URLSessionWebSocketTask.Message.data(data)

            try await webSocketTask.send(message)
        } catch {
            log.error("Failed to send message: \(error)")
        }
    }

    private func startListening() async {
        guard let webSocketTask = webSocketTask else {
            log.warning("WebSocket not connected, cannot start listening")
            return
        }

        do {
            let message = try await webSocketTask.receive()
            await handleMessage(message)

            // Continue listening
            await startListening()
        } catch {
            await handleError(error)
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) async {
        switch message {
        case .string:
            log.warning("Received invalid websocket message type 'String'")
            break
        case .data(let data):
                log.trace("Received websocket message (\(data.count) bytes))")
            guard let envelope = try? decoder.decode(TypeEnvelope.self, from: data) else {
                log.warning("Failed to decode message envelope")
                return
            }

            guard let handler = messageHandlers[envelope.type] else {
                log.debug("No handler registered for message type '\(envelope.type)'")
                return
            }

            do {
                try await handler(data)
            } catch {
                log.error("Failed to handle message of type '\(envelope.type)': \(error)")
            }
        @unknown default:
            log.warning("Received unknown websocket message type")
            break
        }
    }

    private func handleError(_ error: Error) async {
        log.error("WebSocket error: \(error)")
        webSocketTask = nil
        scheduleReconnect()
    }

    private func scheduleReconnect() {
        // Cancel any existing reconnect task
        reconnectTask?.cancel()

        reconnectTask = Task {
            await handleConnectionFailure()
        }
    }

    private func handleConnectionFailure() async {
        reconnectAttempts += 1

        if self.reconnectAttempts > self.maxReconnectAttempts {
            log.error("Max reconnect attempts (\(self.maxReconnectAttempts)) reached, giving up")
            return
        }

        let delay = min(
            baseReconnectDelay * pow(2.0, Double(reconnectAttempts - 1)), maxReconnectDelay)
        log.info(
            "Attempting to reconnect in \(delay) seconds (attempt \(self.reconnectAttempts)/\(self.maxReconnectAttempts))"
        )

        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

        // Check if task was cancelled during sleep
        guard !Task.isCancelled else {
            log.debug("Reconnect task was cancelled")
            return
        }

        await performConnect()
    }

    private func performDisconnect() {
        log.debug("Disconnecting WebSocket")

        // Cancel any pending reconnect task
        reconnectTask?.cancel()
        reconnectTask = nil

        // Close existing connection
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil

        // Reset connection state
        isConnecting = false
        reconnectAttempts = 0
    }
}

extension WebSocketClient: RealTimeCommunication {
    func connect() async {
        Task {
            await performConnect()
        }
    }

    func disconnect() {
        performDisconnect()
    }
}
