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

    @Test func googleCancellationShowsNothing() {
        #expect(AlertMessage.googleFailure(.cancelled) == nil)
        #expect(AlertMessage.googleFailure(.unavailable)?.message.contains("isn't available") == true)
    }
}
