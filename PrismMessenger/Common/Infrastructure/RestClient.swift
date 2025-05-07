//
//  RestClient.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation

private let log = Log.common

enum RestClientError: Error {
    case invalidURL
    case serdeFailed(String)
    case httpError(Int)
    case authenticationRequired
    case unknown
}

enum RestAccessLevel {
    case pub
    case authenticated
}

class RestClient {

    private let session: URLSession
    private let baseURL: URL
    private let userService: UserService

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

    private func authForCurrentUser() async throws -> RestAuthMethod {
        guard let user = try await userService.getCurrentUser() else {
            throw RestClientError.authenticationRequired
        }

        return .basic(username: user.username, password: user.authPassword)
    }

    private func authMethod(for accessLevel: RestAccessLevel) async throws -> RestAuthMethod {
        switch accessLevel {
        case .pub:
            return .none
        case .authenticated:
            return try await authForCurrentUser()
        }
    }

    init(baseURLStr: String = "http://127.0.0.1:8080", userService: UserService) throws {
        guard let baseURL = URL(string: baseURLStr) else {
            throw RestClientError.invalidURL
        }
        self.baseURL = baseURL
        self.userService = userService

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
    }

    func head(from path: String, accessLevel: RestAccessLevel = .pub) async throws
        -> HTTPURLResponse
    {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "HEAD"

        let authMethod = try await authMethod(for: accessLevel)
        try request.applyAuth(authMethod)

        log.debug(
            "\(request.httpMethod!) \(path): \(String(describing: request.allHTTPHeaderFields))"
        )

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw RestClientError.unknown
        }

        return httpResponse
    }

    func fetch<T: Decodable>(from path: String, accessLevel: RestAccessLevel = .pub) async throws
        -> T
    {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "GET"

        // Apply authentication method to the request
        let authMethod = try await authMethod(for: accessLevel)
        try request.applyAuth(authMethod)

        log.debug(
            "\(request.httpMethod!) \(path): \(String(describing: request.allHTTPHeaderFields))"
        )

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RestClientError.unknown
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw RestClientError.httpError(httpResponse.statusCode)
        }

        do {
            return try decoder.decode(T.self, from: data)

        } catch DecodingError.dataCorrupted(let context),
            DecodingError.valueNotFound(_, let context),
            DecodingError.typeMismatch(_, let context),
            DecodingError.keyNotFound(_, let context)
        {
            throw RestClientError.serdeFailed(context.debugDescription)
        }
    }

    func post<T: Encodable>(_ data: T, to path: String, accessLevel: RestAccessLevel = .pub)
        async throws
    {
        let authMethod = try await authMethod(for: accessLevel)
        try await self.post(data, to: path, authMethod: authMethod)
    }

    func post<T: Encodable>(_ data: T, to path: String, authMethod: RestAuthMethod)
        async throws
    {
        let _ = try await self.postForData(data, to: path, authMethod: authMethod)
    }

    func post<T: Encodable, U: Decodable>(
        _ data: T,
        to path: String,
        accessLevel: RestAccessLevel = .pub
    )
        async throws -> U
    {
        let authMethod = try await authMethod(for: accessLevel)
        return try await self.post(data, to: path, authMethod: authMethod)
    }

    func post<T: Encodable, U: Decodable>(
        _ data: T,
        to path: String,
        authMethod: RestAuthMethod
    )
        async throws -> U
    {
        let responseData = try await self.postForData(data, to: path, authMethod: authMethod)
        do {
            return try decoder.decode(U.self, from: responseData)
        } catch DecodingError.dataCorrupted(let context),
            DecodingError.valueNotFound(_, let context),
            DecodingError.typeMismatch(_, let context),
            DecodingError.keyNotFound(_, let context)
        {
            throw RestClientError.serdeFailed(context.debugDescription)
        }
    }

    private func postForData<T: Encodable>(
        _ data: T,
        to path: String,
        authMethod: RestAuthMethod
    ) async throws
        -> Data
    {
        let fullURL = baseURL.appendingPathComponent(path)

        var request = URLRequest(url: fullURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try request.applyAuth(authMethod)

        do {
            request.httpBody = try encoder.encode(data)
            log.debug(
                "\(request.httpMethod!) \(path): \(String(describing: request.allHTTPHeaderFields)) \(String(data: request.httpBody!, encoding: .utf8) ?? "No body")"
            )
        } catch EncodingError.invalidValue(_, let context) {
            throw RestClientError.serdeFailed(context.debugDescription)
        }

        let (responseData, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw RestClientError.unknown
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw RestClientError.httpError(httpResponse.statusCode)
        }
        return responseData
    }

    func put<T: Encodable>(_ data: T, to path: String, accessLevel: RestAccessLevel = .pub)
        async throws
    {
        let authMethod = try await authMethod(for: accessLevel)
        try await self.put(data, to: path, authMethod: authMethod)
    }

    private func put<T: Encodable>(_ data: T, to path: String, authMethod: RestAuthMethod)
        async throws
    {
        let _ = try await self.putForData(data, to: path, authMethod: authMethod)
    }

    private func putForData<T: Encodable>(
        _ data: T,
        to path: String,
        authMethod: RestAuthMethod
    ) async throws -> Data {
        let fullURL = baseURL.appendingPathComponent(path)

        var request = URLRequest(url: fullURL)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try request.applyAuth(authMethod)

        do {
            request.httpBody = try encoder.encode(data)
            log.debug(
                "\(request.httpMethod!) \(path): \(String(describing: request.allHTTPHeaderFields)) \(String(data: request.httpBody!, encoding: .utf8) ?? "No body")"
            )
        } catch EncodingError.invalidValue(_, let context) {
            throw RestClientError.serdeFailed(context.debugDescription)
        }

        let (responseData, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw RestClientError.unknown
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw RestClientError.httpError(httpResponse.statusCode)
        }
        return responseData
    }
}
