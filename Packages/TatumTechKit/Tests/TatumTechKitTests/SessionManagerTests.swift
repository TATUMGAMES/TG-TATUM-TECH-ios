import Foundation
import Testing
@testable import TatumTechKit

@Suite("SessionManager")
struct SessionManagerTests {

    private let clock = TestClock()
    private let storage = InMemorySecureStore()

    private var store: SecureValue<TatumTechSession> { SecureValue(store: storage, key: "session") }

    private func manager(_ transport: FakeTransport) -> SessionManager {
        let clock = self.clock
        return SessionManager(
            client: Fixtures.client(transport),
            store: store,
            deviceIdentifier: FixedDeviceIdentifier("device-1"),
            now: { clock.now }
        )
    }

    private func seed(expiresIn interval: TimeInterval?, refreshToken: String? = "refresh-1") throws {
        try store.save(TatumTechSession(
            accessToken: "access-1",
            refreshToken: refreshToken,
            expiresAt: interval.map { clock.now.addingTimeInterval($0) },
            authMethod: .email
        ))
    }

    @Test func signInPersistsTheSession() async throws {
        let manager = manager(FakeTransport(json: Fixtures.authEnvelope()))
        let session = try await manager.signIn(email: "ada@example.com", password: "Secret!")

        #expect(session.accessToken == "access-1")
        #expect(session.expiresAt == clock.now.addingTimeInterval(86_400))
        #expect(session.user?.firstName == "Ada")
        #expect(store.load() == session)
        #expect(await manager.isSignedIn)
    }

    @Test func responseWithoutAccessTokenFailsAndStoresNothing() async {
        let manager = manager(FakeTransport(json: Fixtures.envelope(#"{"refreshToken":"r"}"#)))
        await #expect(throws: APIError.decoding("Auth response has no accessToken")) {
            try await manager.signIn(email: "a@b.co", password: "Secret!")
        }
        #expect(store.load() == nil)
    }

    @Test func storageFailureFailsSignIn() async {
        storage.failWrites = SecureStoreError(status: -1)
        let manager = manager(FakeTransport(json: Fixtures.authEnvelope()))
        await #expect(throws: APIError.self) { try await manager.signIn(email: "a@b.co", password: "Secret!") }
        #expect(await manager.isSignedIn == false)
    }

    @Test func restoresStoredSessionAtInit() async throws {
        try seed(expiresIn: 86_400)
        let manager = manager(FakeTransport(json: "{}"))
        #expect(await manager.currentSession?.accessToken == "access-1")
    }

    @Test func refreshIsSkippedWhileTokenIsFresh() async throws {
        try seed(expiresIn: 2 * 3600)
        let transport = FakeTransport(json: Fixtures.authEnvelope(access: "access-2"))
        #expect(await manager(transport).refreshIfNeeded() == .notNeeded)
        #expect(transport.requests.isEmpty)
    }

    @Test func refreshesWithinTheWindowAndKeepsRefreshTokenWhenOmitted() async throws {
        try seed(expiresIn: 30 * 60)
        let transport = FakeTransport(json: Fixtures.authEnvelope(access: "access-2", refresh: nil, expiresIn: 3600))
        let manager = manager(transport)

        #expect(await manager.refreshIfNeeded() == .refreshed)
        let session = await manager.currentSession
        #expect(session?.accessToken == "access-2")
        #expect(session?.refreshToken == "refresh-1")
        #expect(session?.expiresAt == clock.now.addingTimeInterval(3600))
        #expect(transport.requests.first?.headers["Authorization"] == "Bearer access-1")
        #expect(store.load()?.accessToken == "access-2")
    }

    @Test func concurrentRefreshesShareOneRequest() async throws {
        try seed(expiresIn: 60)
        let transport = FakeTransport { _ in
            try await Task.sleep(for: .milliseconds(100))
            return HTTPResponse(statusCode: 200, body: Data(Fixtures.authEnvelope(access: "access-2").utf8))
        }
        let manager = manager(transport)
        async let first = manager.refreshIfNeeded()
        async let second = manager.refreshIfNeeded()
        let results = await [first, second]

        #expect(results == [.refreshed, .refreshed])
        #expect(transport.requests.count == 1)
    }

    @Test(arguments: [400, 401, 403])
    func rejectedRefreshSignsOut(status: Int) async throws {
        try seed(expiresIn: 60)
        let manager = manager(FakeTransport(statusCode: status, json: "{}"))
        #expect(await manager.refreshIfNeeded() == .signedOut)
        #expect(await manager.isSignedIn == false)
        #expect(store.load() == nil)
    }

    @Test func networkFailureKeepsTheSession() async throws {
        try seed(expiresIn: 60)
        let manager = manager(FakeTransport { _ in throw URLError(.notConnectedToInternet) })
        let result = await manager.refreshIfNeeded()
        guard case .failed(let error) = result else { Issue.record("Expected failure, got \(result)"); return }
        #expect(error.isNetworkFailure)
        #expect(await manager.isSignedIn)
    }

    @Test func authenticatedRetriesOnceAfter401() async throws {
        try seed(expiresIn: 86_400)
        let transport = FakeTransport { request in
            switch request.url.path {
            case "/tatum-tech/refreshToken":
                return HTTPResponse(statusCode: 200, body: Data(Fixtures.authEnvelope(access: "access-2").utf8))
            default:
                let authorized = request.headers["Authorization"] == "Bearer access-2"
                return HTTPResponse(statusCode: authorized ? 200 : 401, body: Data("{}".utf8))
            }
        }
        let manager = manager(transport)
        try await manager.authenticated { client, token in
            try await client.updateUserProfile(firstName: "Ada", lastName: nil, accessToken: token)
        }
        #expect(transport.requests.map(\.url.path) == [
            "/tatum-tech/updateUserProfile", "/tatum-tech/refreshToken", "/tatum-tech/updateUserProfile"
        ])
    }

    @Test func authenticatedWithoutSessionIsUnauthorized() async {
        let manager = manager(FakeTransport(json: "{}"))
        await #expect(throws: APIError.http(statusCode: 401, messages: [])) {
            try await manager.authenticated { client, token in try await client.signOut(accessToken: token) }
        }
    }

    @Test func signOutClearsEvenWhenTheServerFails() async throws {
        try seed(expiresIn: 86_400)
        let transport = FakeTransport(statusCode: 500, json: "{}")
        let manager = manager(transport)
        await manager.signOut()
        #expect(await manager.isSignedIn == false)
        #expect(store.load() == nil)
        #expect(transport.requests.map(\.url.path) == ["/tatum-tech/signout"])
    }

    @Test func confirmedSignOutPostsAnEmptyBodyWithTheBearerTokenAndClearsTheSession() async throws {
        try seed(expiresIn: 86_400)
        let transport = FakeTransport(json: #"{"status":{"statusCode":200,"statusMessage":"OK"},"data":{}}"#)
        let manager = manager(transport)

        try await manager.signOutOrFail()

        let request = try #require(transport.requests.first)
        #expect(transport.requests.count == 1)
        #expect(request.method == .post)
        #expect(request.url.path == "/tatum-tech/signout")
        #expect(request.headers["Authorization"] == "Bearer access-1")
        #expect(request.body.map { String(decoding: $0, as: UTF8.self) } == "{}")
        #expect(await manager.isSignedIn == false)
        #expect(store.load() == nil)
    }

    @Test func failedSignOutKeepsTheSession() async throws {
        try seed(expiresIn: 86_400)
        let manager = manager(FakeTransport(statusCode: 500, json: "{}"))

        await #expect(throws: APIError.http(statusCode: 500, messages: [])) { try await manager.signOutOrFail() }

        #expect(await manager.isSignedIn)
        #expect(store.load()?.accessToken == "access-1")
    }

    @Test func signOutRejectedInsideAnHTTP200EnvelopeKeepsTheSession() async throws {
        try seed(expiresIn: 86_400)
        let manager = manager(FakeTransport(json: #"{"status":{"statusCode":500,"statusMessage":"Server error"}}"#))

        await #expect(throws: APIError.self) { try await manager.signOutOrFail() }

        #expect(await manager.isSignedIn)
    }

    @Test func offlineSignOutKeepsTheSession() async throws {
        try seed(expiresIn: 86_400)
        let manager = manager(FakeTransport { _ in throw URLError(.notConnectedToInternet) })

        await #expect(throws: APIError.self) { try await manager.signOutOrFail() }

        #expect(await manager.isSignedIn)
    }

    @Test func signOutOfASessionTheServerAlreadyRejectedCountsAsSignedOut() async throws {
        try seed(expiresIn: 86_400)
        let transport = FakeTransport(statusCode: 401, json: "{}")
        let manager = manager(transport)

        try await manager.signOutOrFail()

        #expect(transport.requests.map(\.url.path) == ["/tatum-tech/signout", "/tatum-tech/refreshToken"])
        #expect(await manager.isSignedIn == false)
        #expect(store.load() == nil)
    }

    @Test func confirmedSignOutWithoutASessionSendsNothing() async throws {
        let transport = FakeTransport(json: "{}")

        try await manager(transport).signOutOrFail()

        #expect(transport.requests.isEmpty)
    }

    @Test func profileUpdatePostsBothNamesWithTheBearerToken() async throws {
        try seed(expiresIn: 86_400)
        let transport = FakeTransport(json: #"{"status":{"statusCode":200,"statusMessage":"OK"},"data":{}}"#)

        try await manager(transport).updateUserProfile(firstName: "Tatum2", lastName: "Tech1")

        let request = try #require(transport.requests.first)
        #expect(transport.requests.count == 1)
        #expect(request.method == .post)
        #expect(request.url.path == "/tatum-tech/updateUserProfile")
        #expect(request.headers["Authorization"] == "Bearer access-1")
        #expect(try bodyFields(request) == ["firstName": "Tatum2", "lastName": "Tech1"])
    }

    @Test func profileUpdateLeavesMissingNamesOutOfTheBody() async throws {
        try seed(expiresIn: 86_400)
        let transport = FakeTransport(json: #"{"status":{"statusCode":200,"statusMessage":"OK"},"data":{}}"#)
        let manager = manager(transport)

        try await manager.updateUserProfile(firstName: "Ada", lastName: nil)
        try await manager.updateUserProfile(firstName: nil, lastName: nil)

        #expect(try transport.requests.map(bodyFields) == [["firstName": "Ada"], [:]])
    }

    @Test func failedProfileUpdateThrowsAndKeepsTheSession() async throws {
        try seed(expiresIn: 86_400)
        let manager = manager(FakeTransport(statusCode: 500, json: "{}"))

        await #expect(throws: APIError.http(statusCode: 500, messages: [])) {
            try await manager.updateUserProfile(firstName: "Ada", lastName: "Lovelace")
        }

        #expect(await manager.isSignedIn)
    }

    @Test func profileUpdateWithoutASessionSendsNothing() async throws {
        let transport = FakeTransport(json: "{}")

        try await manager(transport).updateUserProfile(firstName: "Ada", lastName: "Lovelace")

        #expect(transport.requests.isEmpty)
    }

    private func bodyFields(_ request: HTTPRequest) throws -> [String: String] {
        let body = try #require(request.body)
        return try #require(try JSONSerialization.jsonObject(with: body) as? [String: String])
    }

    @Test func refreshFinishingAfterSignOutDoesNotRestoreTheSession() async throws {
        try seed(expiresIn: 60)
        let transport = FakeTransport { request in
            if request.url.path == "/tatum-tech/refreshToken" {
                try await Task.sleep(for: .milliseconds(150))
                return HTTPResponse(statusCode: 200, body: Data(Fixtures.authEnvelope(access: "access-2").utf8))
            }
            return HTTPResponse(statusCode: 200, body: Data("{}".utf8))
        }
        let manager = manager(transport)
        async let refresh = manager.refreshIfNeeded(force: true)
        try await Task.sleep(for: .milliseconds(30))
        let signOut = Task { await manager.signOut() }
        _ = await refresh
        await signOut.value

        #expect(await manager.isSignedIn == false)
        #expect(store.load() == nil)
    }
}
