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

    @MainActor
    private func authForCurrentUser() async throws -> RestAuthMethod {
        guard let user = userService.currentUser else {
            throw RestClientError.authenticationRequired
        }

        return .basic(username: user.id.uuidString, password: user.authPassword)
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
        async throws -> U?
    {
        let authMethod = try await authMethod(for: accessLevel)
        return try await self.post(data, to: path, authMethod: authMethod)
    }

    func post<T: Encodable, U: Decodable>(
        _ data: T,
        to path: String,
        authMethod: RestAuthMethod
    )
        async throws -> U?
    {
        guard let responseData = try await self.postForData(data, to: path, authMethod: authMethod)
        else {
            return nil
        }

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
        -> Data?
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

        if httpResponse.statusCode == 204 {
            return nil
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
    ) async throws -> Data? {
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

        if httpResponse.statusCode == 204 {
            return nil
        }

        return responseData
    }

    func patch<T: Encodable>(_ data: T, to path: String, accessLevel: RestAccessLevel = .pub)
        async throws
    {
        let authMethod = try await authMethod(for: accessLevel)
        try await patch(data, to: path, authMethod: authMethod)
    }

    private func patch<T: Encodable>(_ data: T, to path: String, authMethod: RestAuthMethod)
        async throws
    {
        let _ = try await patchForData(data, to: path, authMethod: authMethod)
    }

    func patch<T: Encodable, U: Decodable>(
        _ data: T,
        to path: String,
        accessLevel: RestAccessLevel = .pub
    )
        async throws -> U?
    {
        let authMethod = try await authMethod(for: accessLevel)
        return try await patch(data, to: path, authMethod: authMethod)
    }

    private func patch<T: Encodable, U: Decodable>(
        _ data: T,
        to path: String,
        authMethod: RestAuthMethod
    )
        async throws -> U?
    {
        guard let responseData = try await patchForData(data, to: path, authMethod: authMethod)
        else {
            return nil
        }

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

    private func patchForData<T: Encodable>(
        _ data: T,
        to path: String,
        authMethod: RestAuthMethod
    ) async throws -> Data? {
        let fullURL = baseURL.appendingPathComponent(path)

        var request = URLRequest(url: fullURL)
        request.httpMethod = "PATCH"
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

        if httpResponse.statusCode == 204 {
            return nil
        }

        return responseData
    }

    /// Uploads binary data to a specified URL with the given content type using PUT method
    /// - Parameters:
    ///   - data: The binary data to upload
    ///   - url: The URL where the data should be uploaded
    ///   - contentType: The Content-Type header value for the data
    /// - Throws: RestClientError if the upload fails
    func putBinaryData(_ data: Data, to url: String, contentType: String) async throws {
        guard let url = URL(string: url) else {
            throw RestClientError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")

        log.debug(
            "\(request.httpMethod!) \(request.url?.relativePath ?? "/"): \(String(describing: request.allHTTPHeaderFields)) (\(data.count) bytes)"
        )

        let (_, response) = try await session.upload(for: request, from: data)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw RestClientError.unknown
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw RestClientError.httpError(httpResponse.statusCode)
        }
    }
}
