import Foundation
import Testing
@testable import TatumTechKit

@Suite("AccountService")
struct AccountServiceTests {

    private let storage = InMemorySecureStore()
    private let firebase = InMemoryFirebaseAuthentication()

    private func service(_ transport: FakeTransport) -> AccountService {
        let sessions = SessionManager(
            client: Fixtures.client(transport),
            store: SecureValue(store: storage, key: "session"),
            deviceIdentifier: FixedDeviceIdentifier("device-1")
        )
        return AccountService(
            sessionManager: sessions,
            federatedStore: SecureValue(store: storage, key: "federated"),
            firebase: firebase
        )
    }

    private func apple(
        _ userID: String = "a-1",
        token: String? = "apple-token-1",
        nonce: String? = "raw-nonce",
        code: String? = nil,
        email: String? = nil,
        givenName: String? = nil,
        familyName: String? = nil
    ) -> AppleIdentity {
        let name = [givenName, familyName].compactMap { $0 }.joined(separator: " ")
        return AppleIdentity(
            userID: userID,
            identityToken: token,
            rawNonce: nonce,
            authorizationCode: code,
            email: email,
            displayName: name.isEmpty ? nil : name,
            givenName: givenName,
            familyName: familyName
        )
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

    // MARK: Google

    @Test func googleSignsInToFirebaseThenExchangesWithTheAPI() async throws {
        let transport = FakeTransport(json: Fixtures.authEnvelope())
        let result = try await service(transport).completeGoogleSignIn(
            GoogleIdentity(idToken: "id-token", accessToken: "access", userID: "g-1", email: "ada@gmail.com", displayName: "Ada")
        )
        #expect(result.exchangeError == nil)
        #expect(result.isNewUser)
        guard case .signedIn(let summary) = result.state else { Issue.record("Expected signed in"); return }
        #expect(summary.method == .google)
        #expect(summary.hasAPISession)
        #expect(summary.federatedAccount?.userID == "g-1")
        #expect(summary.federatedAccount?.firebaseUID == firebase.currentUserID)
        #expect(Fixtures.json(try #require(transport.requests.first))["googleIdToken"] as? String == "id-token")
    }

    /// A failed API exchange still enters with a Google (Firebase) session.
    @Test func googleSignInContinuesWhenExchangeFails() async throws {
        let service = service(FakeTransport(statusCode: 404, json: "{}"))
        let result = try await service.completeGoogleSignIn(GoogleIdentity(idToken: "id-token", userID: "g-1"))

        #expect((result.exchangeError as? APIError)?.statusCode == 404)
        guard case .signedIn(let summary) = result.state else { Issue.record("Expected signed in"); return }
        #expect(summary.method == .google)
        #expect(!summary.hasAPISession)
        #expect(await service.state() == result.state)
    }

    @Test func googleFirebaseFailureStoresNothingAndSkipsTheExchange() async {
        let transport = FakeTransport(json: Fixtures.authEnvelope())
        let service = service(transport)
        firebase.failNext(with: .network)
        await #expect(throws: FirebaseAuthFailure.network) {
            _ = try await service.completeGoogleSignIn(GoogleIdentity(idToken: "id-token", userID: "g-1"))
        }
        #expect(transport.requests.isEmpty)
        #expect(await service.state() == .signedOut)
        #expect(await service.federatedAccount == nil)
    }

    // MARK: Apple

    @Test func newAppleUserSignsInThroughFirebase() async throws {
        let service = service(FakeTransport(json: "{}"))
        let result = try await service.completeAppleSignIn(
            apple(email: "ada@privaterelay.appleid.com", givenName: "Ada", familyName: "Lovelace")
        )

        #expect(result.isNewUser)
        guard case .signedIn(let summary) = result.state else { Issue.record("Expected signed in"); return }
        #expect(summary.method == .apple)
        #expect(!summary.hasAPISession)
        let account = try #require(summary.federatedAccount)
        #expect(account.email == "ada@privaterelay.appleid.com")
        #expect(account.displayName == "Ada Lovelace")
        #expect(account.givenName == "Ada")
        #expect(account.familyName == "Lovelace")
        #expect(account.firebaseUID == firebase.currentUserID)
    }

    @Test func returningAppleUserKeepsNameAndEmailFromTheFirstAuthorization() async throws {
        let service = service(FakeTransport(json: "{}"))
        _ = try await service.completeAppleSignIn(
            apple(email: "ada@privaterelay.appleid.com", givenName: "Ada", familyName: "Lovelace")
        )
        let result = try await service.completeAppleSignIn(apple(email: "  ", givenName: ""))

        #expect(!result.isNewUser)
        guard case .signedIn(let summary) = result.state else { Issue.record("Expected signed in"); return }
        #expect(summary.federatedAccount?.displayName == "Ada Lovelace")
        #expect(summary.federatedAccount?.givenName == "Ada")
        #expect(summary.federatedAccount?.email == "ada@privaterelay.appleid.com")
    }

    /// After a reinstall the stored identity is gone and Apple sends no name; Firebase kept it.
    @Test func returningAppleUserRecoversTheNameFromFirebase() async throws {
        let service = service(FakeTransport(json: "{}"))
        _ = try await service.completeAppleSignIn(apple(givenName: "Ada", familyName: "Lovelace"))
        await service.signOut()

        let result = try await service.completeAppleSignIn(apple())

        guard case .signedIn(let summary) = result.state else { Issue.record("Expected signed in"); return }
        #expect(summary.federatedAccount?.displayName == "Ada Lovelace")
    }

    @Test func appleSignInWithoutTokenOrNonceIsRejectedBeforeFirebase() async {
        let service = service(FakeTransport(json: "{}"))
        await #expect(throws: AppleSignInFailure.missingIdentityToken) {
            _ = try await service.completeAppleSignIn(apple(token: nil))
        }
        await #expect(throws: AppleSignInFailure.invalidNonce) {
            _ = try await service.completeAppleSignIn(apple(nonce: " "))
        }
        #expect(firebase.currentUserID == nil)
        #expect(await service.state() == .signedOut)
    }

    @Test(arguments: [
        FirebaseAuthFailure.invalidCredential, .invalidNonce, .network, .accountExistsWithDifferentCredential,
        .providerDisabled, .failed("FIRAuthErrorDomain 17999")
    ])
    func appleFirebaseFailureLeavesTheUserSignedOut(_ failure: FirebaseAuthFailure) async {
        let service = service(FakeTransport(json: "{}"))
        firebase.failNext(with: failure)
        await #expect(throws: failure) {
            _ = try await service.completeAppleSignIn(apple(givenName: "Ada"))
        }
        #expect(await service.state() == .signedOut)
        #expect(await service.federatedAccount == nil)
    }

    @Test func aStoredIdentityWithoutItsFirebaseSessionIsSignedOut() async throws {
        let service = service(FakeTransport(json: "{}"))
        _ = try await service.completeAppleSignIn(apple())
        firebase.signOut()
        #expect(await service.state() == .signedOut)
    }

    // MARK: Sign-out and deletion

    @Test func signOutForgetsEveryIdentityAndFirebase() async throws {
        let transport = FakeTransport(json: Fixtures.authEnvelope())
        let service = service(transport)
        _ = try await service.completeGoogleSignIn(GoogleIdentity(idToken: "id-token", userID: "g-1"))
        await service.signOut()

        #expect(await service.state() == .signedOut)
        #expect(firebase.currentUserID == nil)
        #expect(transport.requests.last?.url.path == "/tatum-tech/signout")
    }

    @Test func appleUserCanSignOutAndSignBackIn() async throws {
        let service = service(FakeTransport(json: "{}"))
        let first = try await service.completeAppleSignIn(apple(givenName: "Ada"))
        await service.signOut()
        #expect(await service.state() == .signedOut)

        let again = try await service.completeAppleSignIn(apple())
        guard case .signedIn(let before) = first.state, case .signedIn(let after) = again.state else {
            Issue.record("Expected signed in"); return
        }
        #expect(after.federatedAccount?.firebaseUID == before.federatedAccount?.firebaseUID)
    }

    @Test func deletingAnAppleAccountRevokesTokensThenDeletesTheFirebaseUser() async throws {
        let service = service(FakeTransport(json: "{}"))
        _ = try await service.completeAppleSignIn(apple())
        let uid = try #require(firebase.currentUserID)

        try await service.deleteAccount(appleReauthorization: apple(token: "fresh-token", nonce: "fresh-nonce", code: "auth-code"))

        #expect(firebase.revokedAuthorizationCodes == ["auth-code"])
        #expect(firebase.deletedUserIDs == [uid])
        #expect(await service.state() == .signedOut)
    }

    @Test func appleDeletionNeedsAFreshAuthorizationForTheSameAppleID() async throws {
        let service = service(FakeTransport(json: "{}"))
        _ = try await service.completeAppleSignIn(apple())

        await #expect(throws: AppleSignInFailure.invalidCredential) {
            try await service.deleteAccount(appleReauthorization: nil)
        }
        await #expect(throws: AppleSignInFailure.invalidCredential) {
            try await service.deleteAccount(appleReauthorization: apple("someone-else", code: "auth-code"))
        }
        await #expect(throws: AppleSignInFailure.missingAuthorizationCode) {
            try await service.deleteAccount(appleReauthorization: apple(code: nil))
        }
        #expect(firebase.deletedUserIDs.isEmpty)
        guard case .signedIn = await service.state() else { Issue.record("Expected to stay signed in"); return }
    }

    @Test func failedAppleDeletionKeepsTheAccountSoTheUserCanRetry() async throws {
        let service = service(FakeTransport(json: "{}"))
        _ = try await service.completeAppleSignIn(apple())
        firebase.failNext(with: .network)

        await #expect(throws: FirebaseAuthFailure.network) {
            try await service.deleteAccount(appleReauthorization: apple(code: "auth-code"))
        }
        guard case .signedIn = await service.state() else { Issue.record("Expected to stay signed in"); return }
    }

    @Test func googleDeletionIsBestEffort() async throws {
        let service = service(FakeTransport(json: Fixtures.authEnvelope()))
        _ = try await service.completeGoogleSignIn(GoogleIdentity(idToken: "id-token", userID: "g-1"))
        firebase.failNext(with: .requiresRecentLogin)

        let remoteError = try await service.deleteAccount()

        #expect(remoteError as? FirebaseAuthFailure == .requiresRecentLogin)
        #expect(await service.state() == .signedOut)
    }
}

@Suite("Federated sign-in copy")
struct FederatedSignInCopyTests {
    @Test func cancellationShowsNothing() {
        #expect(FederatedSignInCopy(error: AppleSignInFailure.cancelled) == nil)
        #expect(FederatedSignInCopy(error: GoogleSignInFailure.cancelled) == nil)
        #expect(FederatedSignInCopy(error: CancellationError()) == nil)
    }

    @Test func failuresMapToTheirMessages() {
        #expect(FederatedSignInCopy(error: FirebaseAuthFailure.network) == .network)
        #expect(FederatedSignInCopy(error: GoogleSignInFailure.network) == .network)
        #expect(FederatedSignInCopy(error: APIError.network("offline")) == .network)
        #expect(FederatedSignInCopy(error: FirebaseAuthFailure.unavailable) == .unavailable)
        #expect(FederatedSignInCopy(error: FirebaseAuthFailure.providerDisabled) == .unavailable)
        #expect(FederatedSignInCopy(error: FirebaseAuthFailure.accountExistsWithDifferentCredential) == .accountExists)
        #expect(FederatedSignInCopy(error: FirebaseAuthFailure.credentialAlreadyInUse) == .accountExists)
        #expect(FederatedSignInCopy(error: FirebaseAuthFailure.userDisabled) == .disabled)
        #expect(FederatedSignInCopy(error: FirebaseAuthFailure.invalidCredential) == .failed)
        #expect(FederatedSignInCopy(error: FirebaseAuthFailure.invalidNonce) == .failed)
        #expect(FederatedSignInCopy(error: AppleSignInFailure.missingIdentityToken) == .failed)
        #expect(FederatedSignInCopy(error: AppleSignInFailure.invalidCredential) == .failed)
        #expect(FederatedSignInCopy(error: CocoaError(.fileNoSuchFile)) == .failed)
    }

    @Test func authEventsCarryTheMethod() {
        #expect(AnalyticsEvent.login(method: .apple).name == "login")
        #expect(AnalyticsEvent.login(method: .apple).parameters == ["method": .string("apple")])
        #expect(AnalyticsEvent.signUp(method: .google).name == "sign_up")
        #expect(AnalyticsEvent.signUp(method: .email).parameters == ["method": .string("email")])
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
