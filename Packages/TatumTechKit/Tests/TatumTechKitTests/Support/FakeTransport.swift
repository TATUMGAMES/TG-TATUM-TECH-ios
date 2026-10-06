import Foundation
@testable import TatumTechKit

/// Records requests and answers them with a scripted handler.
final class FakeTransport: HTTPTransport, @unchecked Sendable {
    typealias Handler = @Sendable (HTTPRequest) async throws -> HTTPResponse

    private let lock = NSLock()
    private var recorded: [HTTPRequest] = []
    private let handler: Handler

    init(handler: @escaping Handler) {
        self.handler = handler
    }

    /// Always answers `statusCode` with `json`.
    convenience init(statusCode: Int = 200, json: String) {
        self.init { _ in HTTPResponse(statusCode: statusCode, body: Data(json.utf8)) }
    }

    var requests: [HTTPRequest] {
        lock.lock(); defer { lock.unlock() }
        return recorded
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        lock.withLock { recorded.append(request) }
        return try await handler(request)
    }
}

enum Fixtures {
    static let baseURL = URL(string: "https://api.example.com")!

    static func client(_ transport: some HTTPTransport, apiKey: String? = nil) -> TatumTechAPIClient {
        TatumTechAPIClient(baseURL: baseURL, apiKey: apiKey, transport: transport)
    }

    static func envelope(_ data: String) -> String {
        #"{"status":{"statusCode":200,"statusMessage":"OK"},"data":\#(data)}"#
    }

    static func authEnvelope(access: String = "access-1", refresh: String? = "refresh-1", expiresIn: Int? = 86_400) -> String {
        var fields = [#""accessToken":"\#(access)""#]
        if let refresh { fields.append(#""refreshToken":"\#(refresh)""#) }
        if let expiresIn { fields.append(#""expiresIn":\#(expiresIn)"#) }
        fields.append(#""user":{"id":42,"firstName":"Ada","email":"ada@example.com"}"#)
        return envelope("{\(fields.joined(separator: ","))}")
    }

    static func json(_ request: HTTPRequest) -> [String: Any] {
        guard let body = request.body,
              let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
        else { return [:] }
        return object
    }

    /// Reads a file from the app's bundled content, so tests validate what actually ships.
    static func appContent(_ name: String) throws -> Data {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // FakeTransport.swift
            .deletingLastPathComponent() // Support
            .deletingLastPathComponent() // TatumTechKitTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // TatumTechKit
            .deletingLastPathComponent() // Packages
            .appendingPathComponent("TatumTech/Resources/Content/\(name)")
        return try Data(contentsOf: url)
    }
}

/// Mutable clock for session-expiry tests.
final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date

    init(_ start: Date = Date(timeIntervalSince1970: 1_800_000_000)) {
        current = start
    }

    var now: Date {
        lock.lock(); defer { lock.unlock() }
        return current
    }

    func advance(by interval: TimeInterval) {
        lock.lock(); defer { lock.unlock() }
        current = current.addingTimeInterval(interval)
    }
}
