import AuthenticationServices
import Testing
import TatumTechKit
@testable import TatumTech

@Suite("Sign in with Apple nonce and errors")
struct AppleSignInAttemptTests {
    @Test func noncesAreLongRandomAndNeverRepeat() throws {
        let nonces = try (0..<200).map { _ in try AppleSignInAttempt().rawNonce }
        #expect(Set(nonces).count == nonces.count)
        let allowed = Set("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        for nonce in nonces {
            #expect(nonce.count == 32)
            #expect(nonce.allSatisfy(allowed.contains))
        }
    }

    @Test func requestCarriesTheSHA256OfTheRawNonce() {
        let attempt = AppleSignInAttempt(rawNonce: "abc")
        #expect(attempt.hashedNonce == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")

        let request = ASAuthorizationAppleIDProvider().createRequest()
        attempt.configure(request)
        #expect(request.nonce == attempt.hashedNonce)
        #expect(request.requestedScopes == [.fullName, .email])
    }

    @Test func closingTheSheetIsACancellation() {
        #expect(AppleSignInFailure(authorizationError: ASAuthorizationError(.canceled)) == .cancelled)
        #expect(AppleSignInFailure(authorizationError: ASAuthorizationError(.invalidResponse)) == .invalidCredential)
        #expect(AppleSignInFailure(authorizationError: ASAuthorizationError(.failed)) == .failed("ASAuthorizationError 1004"))
    }
}

@MainActor
@Suite("Federated sign-in model")
struct FederatedSignInModelTests {
    private let firebase = InMemoryFirebaseAuthentication()
    private let recorder = RecordingAnalyticsClient()

    private func model(google: Result<GoogleIdentity, GoogleSignInFailure> = .failure(.unavailable)) -> FederatedSignInModel {
        FederatedSignInModel(
            account: TestServices.accountService(transport: StubTransport(statusCode: 404, json: "{}"), firebase: firebase),
            google: StubGoogleSignIn(result: google),
            analytics: AnalyticsService(clients: [recorder])
        )
    }

    private func apple(token: String? = "apple-token", nonce: String? = "nonce", givenName: String? = "Ada") -> AppleIdentity {
        AppleIdentity(userID: "a-1", identityToken: token, rawNonce: nonce, email: "ada@privaterelay.appleid.com", givenName: givenName)
    }

    @Test func newAppleUserEntersTheAppSignedInThroughFirebase() async {
        let model = model()
        let state = await model.finishApple(.success(apple()))

        guard case let .signedIn(summary)? = state else { Issue.record("Expected signed in"); return }
        #expect(summary.method == .apple)
        #expect(summary.federatedAccount?.firebaseUID == firebase.currentUserID)
        #expect(model.alert == nil)
        #expect(recorder.events == ["sign_up"])
    }

    @Test func returningAppleUserLogsIn() async {
        let model = model()
        _ = await model.finishApple(.success(apple()))
        let state = await model.finishApple(.success(apple(givenName: nil)))

        guard case .signedIn? = state else { Issue.record("Expected signed in"); return }
        #expect(recorder.events == ["sign_up", "login"])
    }

    @Test func cancellingShowsNothingAndStaysSignedOut() async {
        let model = model()
        let state = await model.finishApple(.failure(AppleSignInFailure.cancelled))
        #expect(state == nil)
        #expect(model.alert == nil)
        #expect(recorder.recordedErrorCount == 0)
        #expect(!model.isWorking)
    }

    @Test(arguments: [AppleSignInFailure.invalidCredential, .missingIdentityToken, .invalidNonce, .failed("x")])
    func appleCredentialProblemsShowTheAppleAlert(_ failure: AppleSignInFailure) async {
        let model = model()
        let state = await model.finishApple(.failure(failure))
        #expect(state == nil)
        #expect(model.alert?.message.contains("sign you in with Apple") == true)
        #expect(recorder.events == ["exception"])
    }

    @Test func missingTokenIsRejected() async {
        let model = model()
        #expect(await model.finishApple(.success(apple(token: nil))) == nil)
        #expect(model.alert?.message.contains("sign you in with Apple") == true)
        #expect(firebase.currentUserID == nil)
    }

    @Test func firebaseNetworkFailureShowsTheConnectionMessage() async {
        let model = model()
        firebase.failNext(with: .network)
        #expect(await model.finishApple(.success(apple())) == nil)
        #expect(model.alert?.message == AlertMessage.networkMessage)
    }

    @Test func emailUsedByAnotherProviderIsExplained() async {
        let model = model()
        firebase.failNext(with: .accountExistsWithDifferentCredential)
        #expect(await model.finishApple(.success(apple())) == nil)
        #expect(model.alert?.message.contains("different sign-in method") == true)
    }

    @Test func unexpectedFirebaseFailureShowsTheGenericAppleMessage() async {
        let model = model()
        firebase.failNext(with: .failed("FIRAuthErrorDomain 17999"))
        #expect(await model.finishApple(.success(apple())) == nil)
        #expect(model.alert?.message.contains("sign you in with Apple") == true)
    }

    @Test func appleIsUnavailableWithoutFirebase() async {
        let model = FederatedSignInModel(
            account: TestServices.accountService(transport: StubTransport(statusCode: 404, json: "{}"), firebase: UnavailableFirebaseAuthentication()),
            google: StubGoogleSignIn(result: .failure(.unavailable)),
            analytics: AnalyticsService(clients: [recorder])
        )
        #expect(await model.finishApple(.success(apple())) == nil)
        #expect(model.alert?.message.contains("Sign in with Apple isn't available") == true)
        #expect(recorder.recordedErrorCount == 0)
    }

    @Test func googleSignsInThroughTheSameFirebasePipeline() async {
        let model = model(google: .success(GoogleIdentity(idToken: "g-token", accessToken: "access", userID: "g-1")))
        let state = await model.signInWithGoogle()

        guard case let .signedIn(summary)? = state else { Issue.record("Expected signed in"); return }
        #expect(summary.method == .google)
        #expect(summary.federatedAccount?.firebaseUID == firebase.currentUserID)
        #expect(recorder.events == ["sign_up"])
    }

    @Test func googleCancellationShowsNothing() async {
        let model = model(google: .failure(.cancelled))
        #expect(await model.signInWithGoogle() == nil)
        #expect(model.alert == nil)
    }
}
