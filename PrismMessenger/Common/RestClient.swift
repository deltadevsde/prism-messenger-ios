//
//  RestClient.swift
//  PrismMessenger
//
//  Copyright © 2025 prism. All rights reserved.
//

import Foundation

enum RestClientError: Error {
    case invalidURL
    case serdeFailed(String)
    case httpError(Int)
    case unknown
}

class RestClient {

    private let session: URLSession
    private let baseURL: URL

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

    init(baseURLStr: String = "http://127.0.0.1:8080") throws {
        guard let baseURL = URL(string: baseURLStr) else {
            throw RestClientError.invalidURL
        }
        self.baseURL = baseURL

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
    }

    func head(from path: String) async throws -> HTTPURLResponse {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "HEAD"

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw RestClientError.unknown
        }

        return httpResponse
    }

    func fetch<T: Decodable>(from path: String) async throws -> T {
        let fullURL = baseURL.appendingPathComponent(path)

        let (data, response) = try await session.data(from: fullURL)

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

    func post<T: Encodable>(_ data: T, to path: String) async throws {
        let _ = try await self.postForData(data, to: path)
    }

    func post<T: Encodable, U: Decodable>(_ data: T, to path: String)
        async throws -> U
    {
        let responseData = try await self.postForData(data, to: path)
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

    private func postForData<T: Encodable>(_ data: T, to path: String) async throws
        -> Data
    {
        let fullURL = baseURL.appendingPathComponent(path)

        var request = URLRequest(url: fullURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try encoder.encode(data)
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
