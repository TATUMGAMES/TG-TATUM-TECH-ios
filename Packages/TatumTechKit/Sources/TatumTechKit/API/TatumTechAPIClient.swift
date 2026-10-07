import Foundation

/// Paths of the Tatum Tech API, relative to the environment's base URL.
enum TatumTechEndpoint {
    static let signIn = "tatum-tech/signin"
    static let signUp = "tatum-tech/signup"
    static let refreshToken = "tatum-tech/refreshToken"
    static let forgotPassword = "tatum-tech/forgotPassword"
    static let resetPassword = "tatum-tech/resetPassword"
    static let signOut = "tatum-tech/signout"
    static let updateUserProfile = "tatum-tech/updateUserProfile"
    static let upcomingEvents = "tatum-tech/upcomingEvents"
    static let events = "tatum-tech/events"
    static let speakers = "speakers"
    static let partners = "tatum-tech/partners"
    static let categoryQuery = "category"
}

/// Values accepted by the `category` query parameter of `partners`.
public enum PartnerCategoryQuery: String, CaseIterable, Sendable {
    case community = "Community"
    case corporate = "Corporate"
    case education = "Education"
    case gameStudios = "Game Studios"
    case government = "Government"
    case technology = "Technology"
}

/// Typed access to the Tatum Tech API.
///
/// Every method returns the unwrapped `data` of the response envelope and throws `APIError`
/// (or `CancellationError`). Endpoints that need a signed-in user take the access token as a
/// parameter; call them through `SessionManager.authenticated(_:)`, which supplies a fresh token.
public struct TatumTechAPIClient: Sendable {
    public let baseURL: URL
    private let apiKey: String?
    private let transport: any HTTPTransport
    private let logger: (any HTTPTrafficLogger)?
    private let failureObserver: (any APIFailureObserver)?

    public init(
        baseURL: URL,
        apiKey: String? = nil,
        transport: any HTTPTransport,
        logger: (any HTTPTrafficLogger)? = nil,
        failureObserver: (any APIFailureObserver)? = nil
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.transport = transport
        self.logger = logger
        self.failureObserver = failureObserver
    }

    // MARK: Authentication

    public func signIn(email: String, password: String, deviceID: String) async throws -> AuthSessionDTO {
        try await data(
            .post, TatumTechEndpoint.signIn,
            body: EmailSignInRequest(email: email, password: password, deviceId: deviceID)
        )
    }

    public func signInWithGoogle(idToken: String, deviceID: String) async throws -> AuthSessionDTO {
        try await data(
            .post, TatumTechEndpoint.signIn,
            body: GoogleSignInRequest(googleIdToken: idToken, deviceId: deviceID)
        )
    }

    public func signUp(
        email: String,
        password: String,
        confirmPassword: String,
        deviceID: String
    ) async throws -> AuthSessionDTO {
        try await data(
            .post, TatumTechEndpoint.signUp,
            body: SignUpRequest(email: email, password: password, confirmPassword: confirmPassword, deviceId: deviceID)
        )
    }

    /// - Parameter previousAccessToken: Sent as `Authorization: Bearer …` when provided.
    public func refreshToken(
        _ refreshToken: String,
        deviceID: String,
        previousAccessToken: String? = nil
    ) async throws -> AuthSessionDTO {
        try await data(
            .post, TatumTechEndpoint.refreshToken,
            body: RefreshTokenRequest(refreshToken: refreshToken, deviceId: deviceID),
            accessToken: previousAccessToken
        )
    }

    public func forgotPassword(email: String) async throws {
        try await send(.post, TatumTechEndpoint.forgotPassword, body: ForgotPasswordRequest(email: email))
    }

    public func resetPassword(
        verifyToken: String,
        password: String,
        confirmPassword: String? = nil,
        email: String? = nil
    ) async throws {
        try await send(
            .post, TatumTechEndpoint.resetPassword,
            body: ResetPasswordRequest(
                verifyToken: verifyToken, password: password, confirmPassword: confirmPassword, email: email
            )
        )
    }

    public func signOut(accessToken: String) async throws {
        try await send(.post, TatumTechEndpoint.signOut, body: EmptyRequest(), accessToken: accessToken)
    }

    /// `nil` names are left unchanged.
    public func updateUserProfile(firstName: String?, lastName: String?, accessToken: String) async throws {
        try await send(
            .post, TatumTechEndpoint.updateUserProfile,
            body: UpdateUserProfileRequest(firstName: firstName, lastName: lastName),
            accessToken: accessToken
        )
    }

    // MARK: Events

    public func upcomingEvents() async throws -> [EventDTO] {
        let payload: EventsPayload = try await data(.get, TatumTechEndpoint.upcomingEvents)
        return payload.events ?? []
    }

    public func event(id: String) async throws -> EventDTO {
        let payload: EventPayload = try await data(.get, eventPath(id))
        return try require(payload.event, "event")
    }

    public func eventSpeakers(eventID: String) async throws -> [SpeakerDTO] {
        let payload: SpeakersPayload = try await data(.get, "\(eventPath(eventID))/\(TatumTechEndpoint.speakers)")
        return payload.speakers ?? []
    }

    // MARK: Partners

    /// - Parameter category: Omit to list every partner.
    public func partners(category: PartnerCategoryQuery? = nil) async throws -> [PartnerDTO] {
        let payload: PartnersPayload = try await data(
            .get, TatumTechEndpoint.partners,
            query: [TatumTechEndpoint.categoryQuery: category?.rawValue]
        )
        return payload.partners ?? []
    }

    public func partner(id: String) async throws -> PartnerDTO {
        let payload: PartnerPayload = try await data(
            .get, "\(TatumTechEndpoint.partners)/\(Self.encodePathSegment(id))"
        )
        return try require(payload.partner, "partner")
    }

    // MARK: Request plumbing

    private func eventPath(_ id: String) -> String {
        "\(TatumTechEndpoint.events)/\(Self.encodePathSegment(id))"
    }

    /// Calls an endpoint whose envelope `data` decodes to `Payload`.
    private func data<Payload: Decodable>(
        _ method: HTTPMethod,
        _ path: String,
        query: [String: String?] = [:],
        body: (any Encodable)? = nil,
        accessToken: String? = nil
    ) async throws -> Payload {
        let clock = ContinuousClock()
        let started = clock.now
        let (request, response) = try await exchange(method, path, query: query, body: body, accessToken: accessToken)
        do {
            let envelope = try JSONDecoder().decode(ResponseEnvelope<Payload>.self, from: response.body)
            return try require(envelope.data, "data")
        } catch {
            let failure = (error as? APIError) ?? APIError.decoding("\(method.rawValue) \(path): \(error)")
            report(failure, for: request, response: response, duration: clock.now - started)
            throw failure
        }
    }

    /// Calls an endpoint whose successful body is irrelevant.
    private func send(
        _ method: HTTPMethod,
        _ path: String,
        body: (any Encodable)?,
        accessToken: String? = nil
    ) async throws {
        _ = try await exchange(method, path, query: [:], body: body, accessToken: accessToken)
    }

    private func exchange(
        _ method: HTTPMethod,
        _ path: String,
        query: [String: String?],
        body: (any Encodable)?,
        accessToken: String?
    ) async throws -> (HTTPRequest, HTTPResponse) {
        let request = try buildRequest(method, path, query: query, body: body, accessToken: accessToken)
        logger?.log(request: request)
        let clock = ContinuousClock()
        let started = clock.now

        let response: HTTPResponse
        do {
            response = try await transport.send(request)
        } catch {
            logger?.log(failure: error, for: request, duration: clock.now - started)
            if Task.isCancelled || error is CancellationError || (error as? URLError)?.code == .cancelled {
                throw CancellationError()
            }
            let detail = String(describing: error)
            let failure = error is TimeoutError || (error as? URLError)?.code == .timedOut
                ? APIError.timeout(detail)
                : APIError.network(detail)
            report(failure, for: request, response: nil, duration: clock.now - started)
            throw failure
        }
        logger?.log(response: response, for: request, duration: clock.now - started)

        guard response.isSuccess else {
            let failure = APIError.http(
                statusCode: response.statusCode,
                messages: ErrorMessageParser.messages(from: response.body)
            )
            report(failure, for: request, response: response, duration: clock.now - started)
            throw failure
        }
        if let failure = Self.envelopeFailure(in: response.body) {
            report(failure, for: request, response: response, duration: clock.now - started)
            throw failure
        }
        return (request, response)
    }

    /// The API answers HTTP 200 even for failures and reports the outcome in `status.statusCode`,
    /// e.g. `{"status":{"statusCode":406,"statusMessage":"PASSWORDS_DO_NOT_MATCH"}}`. Returns that
    /// failure, or `nil` when the body reports success or has no status.
    static func envelopeFailure(in body: Data) -> APIError? {
        guard let json = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any],
              let status = json["status"] as? [String: Any],
              let code = (status["statusCode"] as? Int)
                ?? (status["statusCode"] as? NSNumber)?.intValue
                ?? (status["statusCode"] as? String).flatMap(Int.init),
              code != 0, !(200..<300).contains(code)
        else { return nil }
        let message = (status["statusMessage"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return .http(statusCode: code, messages: [message].compactMap { $0 }.filter { !$0.isEmpty })
    }

    private func report(_ error: APIError, for request: HTTPRequest, response: HTTPResponse?, duration: Duration) {
        failureObserver?.requestFailed(
            APIRequestFailure(
                method: request.method,
                url: request.url,
                durationMilliseconds: duration.wholeMilliseconds,
                error: error,
                responseStatusCode: response?.statusCode,
                responseBody: response?.body
            )
        )
    }

    func buildRequest(
        _ method: HTTPMethod,
        _ path: String,
        query: [String: String?],
        body: (any Encodable)?,
        accessToken: String?
    ) throws -> HTTPRequest {
        // Paths arrive with their segments already percent-encoded, so join them as text rather
        // than with appendingPathComponent, which would encode the "%" a second time.
        var base = baseURL.absoluteString
        while base.hasSuffix("/") { base.removeLast() }
        guard var components = URLComponents(string: base + "/" + path) else {
            throw APIError.unexpected("Invalid URL for path \(path)")
        }
        let queryItems = query
            .compactMap { name, value in value.map { URLQueryItem(name: name, value: $0) } }
            .sorted { $0.name < $1.name }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else {
            throw APIError.unexpected("Invalid URL for path \(path)")
        }

        var headers = ["Accept": "application/json"]
        if let apiKey { headers["x-api-key"] = apiKey }
        if let bearer = BearerToken.header(for: accessToken) { headers["Authorization"] = bearer }

        var bodyData: Data?
        if let body {
            do {
                bodyData = try JSONEncoder().encode(body)
            } catch {
                throw APIError.unexpected("Request body could not be encoded: \(error)")
            }
            headers["Content-Type"] = "application/json; charset=utf-8"
        }
        return HTTPRequest(method: method, url: url, headers: headers, body: bodyData)
    }

    private func require<T>(_ value: T?, _ field: String) throws -> T {
        guard let value else { throw APIError.decoding("Response is missing '\(field)'") }
        return value
    }

    /// Percent-encodes one path segment, e.g. an id in `events/{id}`. `appendingPathComponent`
    /// encodes reserved characters except `/`, which must not split an id into two segments.
    static func encodePathSegment(_ value: String) -> String {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove("/")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}

/// Normalizes access tokens to a single `Bearer <token>` form.
public enum BearerToken {
    static let prefix = "Bearer "

    /// `Bearer <token>`, or `nil` when the token is blank or only a prefix.
    public static func header(for token: String?) -> String? {
        guard let raw = bare(token) else { return nil }
        return prefix + raw
    }

    /// The token without any `Bearer` prefix (any case), or `nil` when blank.
    public static func bare(_ token: String?) -> String? {
        guard var value = token?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        let lowered = value.lowercased()
        if lowered == "bearer" {
            return nil
        }
        if lowered.hasPrefix("bearer ") {
            value = String(value.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
        }
        return value.isEmpty ? nil : value
    }
}
