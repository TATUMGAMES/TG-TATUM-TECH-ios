import Foundation

/// Owns the Tatum Tech API session: signs in, persists the session, refreshes the access token,
/// supplies tokens to authenticated calls, and signs out.
///
/// Session lifetime: the API issues short-lived access tokens (24 hours) and the manager refreshes
/// them with the refresh token shortly before they expire, so an active user stays signed in.
/// When the server rejects the refresh token (400/401/403) the session is cleared; network
/// failures never sign the user out.
public actor SessionManager {
    /// Refresh this long before expiry so requests never carry a just-expired token.
    public static let refreshWindow: TimeInterval = 60 * 60
    public static let signOutTimeout: Duration = .seconds(10)
    static let rejectionStatusCodes: Set<Int> = [400, 401, 403]

    public enum RefreshResult: Equatable, Sendable {
        case noSession
        case notNeeded
        case refreshed
        /// The server rejected the refresh token; the session was cleared.
        case signedOut
        /// Temporary failure (e.g. offline); the session was kept.
        case failed(APIError)
    }

    private let client: TatumTechAPIClient
    private let store: SecureValue<TatumTechSession>
    private let deviceIdentifier: any DeviceIdentifierProvider
    private let now: @Sendable () -> Date

    private var session: TatumTechSession?
    private var refreshTask: Task<RefreshResult, Never>?

    public init(
        client: TatumTechAPIClient,
        store: SecureValue<TatumTechSession>,
        deviceIdentifier: any DeviceIdentifierProvider,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.client = client
        self.store = store
        self.deviceIdentifier = deviceIdentifier
        self.now = now
        self.session = store.load()
    }

    public var currentSession: TatumTechSession? { session }
    public var isSignedIn: Bool { session != nil }

    // MARK: Sign-in

    @discardableResult
    public func signIn(email: String, password: String) async throws -> TatumTechSession {
        let response = try await client.signIn(email: email, password: password, deviceID: deviceIdentifier.deviceID())
        return try start(response, method: .email)
    }

    @discardableResult
    public func signUp(email: String, password: String, confirmPassword: String) async throws -> TatumTechSession {
        let response = try await client.signUp(
            email: email, password: password, confirmPassword: confirmPassword,
            deviceID: deviceIdentifier.deviceID()
        )
        return try start(response, method: .email)
    }

    @discardableResult
    public func signInWithGoogle(idToken: String) async throws -> TatumTechSession {
        let response = try await client.signInWithGoogle(idToken: idToken, deviceID: deviceIdentifier.deviceID())
        return try start(response, method: .google)
    }

    public func forgotPassword(email: String) async throws {
        try await client.forgotPassword(email: email)
    }

    private func start(_ response: AuthSessionDTO, method: AuthMethod) throws -> TatumTechSession {
        let issued = try makeSession(from: response, method: method, previous: nil)
        try persist(issued)
        return issued
    }

    // MARK: Refresh

    /// Refreshes the access token if it expires within `refreshWindow` (or `force` is set).
    /// Concurrent callers share one refresh.
    public func refreshIfNeeded(force: Bool = false) async -> RefreshResult {
        if let refreshTask { return await refreshTask.value }
        guard let current = session else { return .noSession }
        guard force || isNearExpiry(current) else { return .notNeeded }
        guard let refreshToken = current.refreshToken else { return .notNeeded }

        let task = Task { await performRefresh(current: current, refreshToken: refreshToken) }
        refreshTask = task
        let result = await task.value
        refreshTask = nil
        return result
    }

    private func performRefresh(current: TatumTechSession, refreshToken: String) async -> RefreshResult {
        let response: AuthSessionDTO
        do {
            response = try await client.refreshToken(
                refreshToken, deviceID: deviceIdentifier.deviceID(), previousAccessToken: current.accessToken
            )
        } catch let error as APIError {
            guard session == current else { return .noSession }
            if let status = error.statusCode, Self.rejectionStatusCodes.contains(status) {
                clear()
                return .signedOut
            }
            return .failed(error)
        } catch {
            return .failed(.unexpected(String(describing: error)))
        }

        // Signed out (or signed in again) while the refresh was in flight: keep the newer state.
        guard session == current else { return .noSession }
        do {
            try persist(try makeSession(from: response, method: current.authMethod, previous: current))
            return .refreshed
        } catch let error as APIError {
            return .failed(error)
        } catch {
            return .failed(.unexpected(String(describing: error)))
        }
    }

    /// Runs an authenticated call with a fresh access token, refreshing and retrying once if the
    /// server answers 401.
    public func authenticated<T: Sendable>(
        _ call: @Sendable (TatumTechAPIClient, String) async throws -> T
    ) async throws -> T {
        _ = await refreshIfNeeded()
        guard let token = session?.accessToken else {
            throw APIError.http(statusCode: HTTPStatus.unauthorized, messages: [])
        }
        do {
            return try await call(client, token)
        } catch let error as APIError where error.statusCode == HTTPStatus.unauthorized {
            guard await refreshIfNeeded(force: true) == .refreshed, let fresh = session?.accessToken else {
                throw error
            }
            return try await call(client, fresh)
        }
    }

    // MARK: Sign-out

    /// Signs out of the API (best effort, at most `signOutTimeout`) and always clears the local session.
    public func signOut() async {
        if session != nil {
            _ = try? await withTimeout(Self.signOutTimeout) { [self] in
                try await self.authenticated { client, token in try await client.signOut(accessToken: token) }
            }
        }
        clear()
    }

    // MARK: Helpers

    private func isNearExpiry(_ session: TatumTechSession) -> Bool {
        guard let expiresAt = session.expiresAt else { return false }
        return expiresAt.timeIntervalSince(now()) <= Self.refreshWindow
    }

    private func persist(_ newSession: TatumTechSession) throws {
        do {
            try store.save(newSession)
        } catch {
            throw APIError.unexpected("Session could not be saved: \(error)")
        }
        session = newSession
    }

    private func clear() {
        store.clear()
        session = nil
    }

    private func makeSession(
        from response: AuthSessionDTO,
        method: AuthMethod,
        previous: TatumTechSession?
    ) throws -> TatumTechSession {
        guard let accessToken = BearerToken.bare(response.accessToken) else {
            throw APIError.decoding("Auth response has no accessToken")
        }
        return TatumTechSession(
            accessToken: accessToken,
            refreshToken: response.refreshToken?.nonBlank ?? previous?.refreshToken,
            expiresAt: response.expiresIn.map { now().addingTimeInterval(TimeInterval($0)) },
            authMethod: method,
            user: response.user ?? previous?.user
        )
    }
}
