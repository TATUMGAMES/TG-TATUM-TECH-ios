import Testing
import TatumTechKit
@testable import TatumTech

@MainActor
@Suite("Auth form models")
struct AuthModelsTests {
    private let unreachable = TestServices.accountService(transport: StubTransport(statusCode: 500, json: "{}"))

    @Test func signInRequiresValidEmailAndPassword() {
        let model = SignInModel(account: unreachable)
        #expect(!model.canSubmit)
        model.email.text = "ada@example.com"
        model.password.text = "Secret!"
        #expect(model.canSubmit)
        model.password.text = "secret"
        #expect(!model.canSubmit)
    }

    @Test func errorsAppearOnlyAfterTheFieldWasLeft() {
        let model = SignInModel(account: unreachable)
        model.email.text = "not-an-email"
        #expect(!model.showsEmailError)
        model.email.wasEdited = true
        #expect(model.showsEmailError)
        model.email.text = "   "
        #expect(!model.showsEmailError)
    }

    @Test func failedSignInShowsTheServerMessage() async {
        let account = TestServices.accountService(
            transport: StubTransport(statusCode: 401, json: #"{"message":"Invalid credentials"}"#)
        )
        let model = SignInModel(account: account)
        model.email.text = "ada@example.com"
        model.password.text = "Secret!"

        let state = await model.submit()

        #expect(state == nil)
        #expect(model.alert?.message == "Invalid credentials")
        #expect(!model.isSubmitting)
    }

    @Test func successfulSignInReturnsTheSignedInState() async {
        let json = #"{"status":{"statusCode":200,"statusMessage":"OK"},"data":{"accessToken":"a","refreshToken":"r","expiresIn":3600,"user":{"id":1,"firstName":"Ada"}}}"#
        let model = SignInModel(account: TestServices.accountService(transport: StubTransport(statusCode: 200, json: json)))
        model.email.text = "ada@example.com"
        model.password.text = "Secret!"

        let state = await model.submit()

        guard case let .signedIn(summary)? = state else {
            Issue.record("Expected a signed-in state")
            return
        }
        #expect(summary.method == .email)
        #expect(summary.user?.firstName == "Ada")
    }

    @Test func signUpRequiresMatchingPasswords() {
        let model = SignUpModel(account: unreachable)
        model.email.text = "ada@example.com"
        model.password.text = "Secret!"
        model.confirmation.text = "Secret?"
        #expect(!model.canSubmit)
        model.confirmation.wasEdited = true
        #expect(model.showsConfirmationError)
        model.confirmation.text = "Secret!"
        #expect(model.canSubmit)
    }

    @Test func passwordResetConfirmationTracksTheAddress() async {
        let model = ForgotPasswordModel(account: TestServices.accountService(transport: StubTransport(statusCode: 200, json: "{}")))
        model.email.text = "ada@example.com"
        await model.submit()
        #expect(model.didSendEmail)
        model.email.text = "grace@example.com"
        #expect(!model.didSendEmail)
    }

    private func signUpModel(_ transport: any HTTPTransport) -> SignUpModel {
        let model = SignUpModel(account: TestServices.accountService(transport: transport))
        model.email.text = "ada@example.com"
        model.password.text = "Secret!"
        model.confirmation.text = "Secret!"
        return model
    }

    @Test func existingAccountReportedInsideAnHTTP200IsExplained() async {
        let model = signUpModel(StubTransport(statusCode: 200, json: #"{"status":{"statusCode":400,"statusMessage":"USER_ALREADY_EXISTS"},"data":{}}"#))

        let state = await model.submit()

        #expect(state == nil)
        #expect(model.alert?.title == "Unable to Create Your Account")
        #expect(model.alert?.message == AlertMessage.message(for: .accountExists))
        #expect(model.alert?.canRetry == false)
        #expect(!model.isSubmitting)
        #expect(model.canSubmit)
    }

    @Test func offlineSignUpOffersTryAgainWithoutRetryingOnItsOwn() async {
        let transport = OfflineTransport()
        let model = signUpModel(transport)

        _ = await model.submit()

        #expect(model.alert?.title == AlertMessage.defaultTitle)
        #expect(model.alert?.message == AlertMessage.networkMessage)
        #expect(model.alert?.canRetry == true)
        #expect(!model.isSubmitting)
    }

    @Test func missingDeploymentShowsServiceCopyNotRawText() async {
        let html = "<html><head><title>404 Page Not Found</title></head><body>The page you requested was not found.</body></html>"
        let model = signUpModel(StubTransport(statusCode: 404, json: html))

        _ = await model.submit()

        #expect(model.alert?.title == AlertMessage.defaultTitle)
        #expect(model.alert?.message == AlertMessage.message(for: .service))
        #expect(model.alert?.message.contains("404") == false)
    }

    @Test func errorTitlesAreTitleCase() {
        let minorWords: Set<String> = ["a", "an", "and", "the", "to", "of", "in", "on", "for", "or"]
        let titles = [AlertMessage.defaultTitle] + [APIOperation.signIn, .signUp, .forgotPassword, .loadContent].map(AlertMessage.title(for:))
        for title in titles {
            for (index, word) in title.split(separator: " ").enumerated() {
                let capitalized = word.first?.isUppercase == true
                #expect(capitalized || (index > 0 && minorWords.contains(word.lowercased())), "\(title)")
            }
        }
    }

    @Test func federatedCancellationShowsNothing() {
        #expect(AlertMessage.signInFailure(GoogleSignInFailure.cancelled, provider: .google) == nil)
        #expect(AlertMessage.signInFailure(AppleSignInFailure.cancelled, provider: .apple) == nil)
        #expect(AlertMessage.signInFailure(GoogleSignInFailure.unavailable, provider: .google)?.message.contains("isn't available") == true)
    }

    @Test func emailSignInAndSignUpAreLogged() async {
        let json = #"{"status":{"statusCode":200,"statusMessage":"OK"},"data":{"accessToken":"a","refreshToken":"r","expiresIn":3600,"user":{"id":1}}}"#
        let recorder = RecordingAnalyticsClient()
        let analytics = AnalyticsService(clients: [recorder])

        let signIn = SignInModel(account: TestServices.accountService(transport: StubTransport(statusCode: 200, json: json)), analytics: analytics)
        signIn.email.text = "ada@example.com"
        signIn.password.text = "Secret!"
        _ = await signIn.submit()

        let signUp = SignUpModel(account: TestServices.accountService(transport: StubTransport(statusCode: 200, json: json)), analytics: analytics)
        signUp.email.text = "ada@example.com"
        signUp.password.text = "Secret!"
        signUp.confirmation.text = "Secret!"
        _ = await signUp.submit()

        #expect(recorder.events == ["login", "sign_up"])
    }
}
