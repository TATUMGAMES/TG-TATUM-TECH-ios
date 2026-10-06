import Foundation
import Testing
@testable import TatumTechKit

@Suite("AccountService")
struct AccountServiceTests {

    private let storage = InMemorySecureStore()

    private func service(_ transport: FakeTransport) -> AccountService {
        let sessions = SessionManager(
            client: Fixtures.client(transport),
            store: SecureValue(store: storage, key: "session"),
            deviceIdentifier: FixedDeviceIdentifier("device-1")
        )
        return AccountService(sessionManager: sessions, federatedStore: SecureValue(store: storage, key: "federated"))
    }

    @Test func startsSignedOut() async {
        #expect(await service(FakeTransport(json: "{}")).state() == .signedOut)
    }

    @Test func emailSignInTrimsEmailAndReportsApiSession() async throws {
        let transport = FakeTransport(json: Fixtures.authEnvelope())
        let state = try await service(transport).signIn(email: "  ada@example.com ", password: "Secret!")

        #expect(Fixtures.json(try #require(transport.requests.first))["email"] as? String == "ada@example.com")
        guard case .signedIn(let summary) = state else { Issue.record("Expected signed in"); return }
        #expect(summary.method == .email)
        #expect(summary.hasAPISession)
        #expect(summary.user?.id == "42")
    }

    @Test func failedEmailSignInStaysSignedOut() async {
        let service = service(FakeTransport(statusCode: 401, json: #"{"message":"Wrong password"}"#))
        await #expect(throws: APIError.http(statusCode: 401, messages: ["Wrong password"])) {
            _ = try await service.signIn(email: "a@b.co", password: "Secret!")
        }
        #expect(await service.state() == .signedOut)
    }

    @Test func googleSignInWithSuccessfulExchange() async throws {
        let transport = FakeTransport(json: Fixtures.authEnvelope())
        let result = try await service(transport).completeGoogleSignIn(
            GoogleIdentity(idToken: "id-token", userID: "g-1", email: "ada@gmail.com", displayName: "Ada")
        )
        #expect(result.exchangeError == nil)
        guard case .signedIn(let summary) = result.state else { Issue.record("Expected signed in"); return }
        #expect(summary.method == .google)
        #expect(summary.hasAPISession)
        #expect(summary.federatedAccount?.userID == "g-1")
        #expect(Fixtures.json(try #require(transport.requests.first))["googleIdToken"] as? String == "id-token")
    }

    /// The Android app enters with a Google-only session when the API exchange fails; so does iOS.
    @Test func googleSignInContinuesWhenExchangeFails() async throws {
        let service = service(FakeTransport(statusCode: 404, json: "{}"))
        let result = try await service.completeGoogleSignIn(GoogleIdentity(idToken: "id-token", userID: "g-1"))

        #expect((result.exchangeError as? APIError)?.statusCode == 404)
        guard case .signedIn(let summary) = result.state else { Issue.record("Expected signed in"); return }
        #expect(summary.method == .google)
        #expect(!summary.hasAPISession)
        #expect(await service.state() == result.state)
    }

    @Test func appleSignInKeepsNameFromFirstAuthorization() async throws {
        let service = service(FakeTransport(json: "{}"))
        _ = try await service.completeAppleSignIn(AppleIdentity(userID: "a-1", email: "ada@privaterelay.appleid.com", displayName: "Ada"))
        let state = try await service.completeAppleSignIn(AppleIdentity(userID: "a-1"))

        guard case .signedIn(let summary) = state else { Issue.record("Expected signed in"); return }
        #expect(summary.method == .apple)
        #expect(!summary.hasAPISession)
        #expect(summary.federatedAccount?.displayName == "Ada")
        #expect(summary.federatedAccount?.email == "ada@privaterelay.appleid.com")
    }

    @Test func signOutForgetsEveryIdentity() async throws {
        let transport = FakeTransport(json: Fixtures.authEnvelope())
        let service = service(transport)
        _ = try await service.completeGoogleSignIn(GoogleIdentity(idToken: "id-token", userID: "g-1"))
        await service.signOut()

        #expect(await service.state() == .signedOut)
        #expect(transport.requests.last?.url.path == "/tatum-tech/signout")
    }
}

@Suite("CredentialRules")
struct CredentialRulesTests {

    @Test(arguments: ["ada@example.com", "a.b+c@sub.example.co", "x_y%z@d-omain.io"])
    func validEmails(_ email: String) {
        #expect(CredentialRules.isValidEmail(email))
    }

    @Test(arguments: ["", "ada", "ada@", "@example.com", "ada@example", "ada @example.com", "ada@-example.com"])
    func invalidEmails(_ email: String) {
        #expect(!CredentialRules.isValidEmail(email))
    }

    @Test(arguments: ["Secret!", "ABCDE1#", "Pässwört§"])
    func validPasswords(_ password: String) {
        #expect(CredentialRules.isValidPassword(password))
    }

    @Test(arguments: ["Sec!1", "secret!", "Secret1", "Sec ret!", ""])
    func invalidPasswords(_ password: String) {
        #expect(!CredentialRules.isValidPassword(password))
    }
}
