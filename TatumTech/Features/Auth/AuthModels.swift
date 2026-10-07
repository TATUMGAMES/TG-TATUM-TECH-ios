import AuthenticationServices
import Foundation
import Observation
import OSLog
import TatumTechKit

/// Field validation shared by the auth forms. Errors appear only after a field loses focus and
/// is not blank.
struct CredentialField {
    var text = ""
    var wasEdited = false

    var isBlank: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

@MainActor
@Observable
final class SignInModel {
    var email = CredentialField()
    var password = CredentialField()
    var isPasswordRevealed = false
    private(set) var isSubmitting = false
    var alert: AlertMessage?

    private let account: AccountService
    private let analytics: AnalyticsService

    init(account: AccountService, analytics: AnalyticsService = .disabled) {
        self.account = account
        self.analytics = analytics
    }

    var isEmailValid: Bool { CredentialRules.isValidEmail(email.text) }
    var isPasswordValid: Bool { CredentialRules.isValidPassword(password.text) }
    var showsEmailError: Bool { email.wasEdited && !email.isBlank && !isEmailValid }
    var showsPasswordError: Bool { password.wasEdited && !password.isBlank && !isPasswordValid }
    var canSubmit: Bool { isEmailValid && isPasswordValid && !isSubmitting }

    /// - Returns: The signed-in state, or `nil` if sign-in failed (an alert explains why).
    func submit() async -> AccountState? {
        guard canSubmit else { return nil }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let state = try await account.signIn(email: email.text, password: password.text)
            analytics.log(.login(method: .email))
            return state
        } catch is CancellationError {
            return nil
        } catch {
            alert = .authFailure(error)
            return nil
        }
    }
}

@MainActor
@Observable
final class SignUpModel {
    var email = CredentialField()
    var password = CredentialField()
    var confirmation = CredentialField()
    var isPasswordRevealed = false
    var isConfirmationRevealed = false
    private(set) var isSubmitting = false
    var alert: AlertMessage?

    private let account: AccountService
    private let analytics: AnalyticsService

    init(account: AccountService, analytics: AnalyticsService = .disabled) {
        self.account = account
        self.analytics = analytics
    }

    var isEmailValid: Bool { CredentialRules.isValidEmail(email.text) }
    var isPasswordValid: Bool { CredentialRules.isValidPassword(password.text) }
    var passwordsMatch: Bool { !confirmation.text.isEmpty && confirmation.text == password.text }
    var showsEmailError: Bool { email.wasEdited && !email.isBlank && !isEmailValid }
    var showsPasswordError: Bool { password.wasEdited && !password.isBlank && !isPasswordValid }
    var showsConfirmationError: Bool { confirmation.wasEdited && !confirmation.isBlank && !passwordsMatch }
    var canSubmit: Bool { isEmailValid && isPasswordValid && passwordsMatch && !isSubmitting }

    func submit() async -> AccountState? {
        guard canSubmit else { return nil }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let state = try await account.signUp(email: email.text, password: password.text, confirmPassword: confirmation.text)
            analytics.log(.signUp(method: .email))
            return state
        } catch is CancellationError {
            return nil
        } catch {
            alert = .authFailure(error)
            return nil
        }
    }
}

@MainActor
@Observable
final class ForgotPasswordModel {
    var email = CredentialField()
    private(set) var isSubmitting = false
    private var emailSentTo: String?
    var alert: AlertMessage?

    /// Whether a reset email went to the address currently in the field.
    var didSendEmail: Bool { emailSentTo != nil && emailSentTo == email.text }

    private let account: AccountService

    init(account: AccountService) {
        self.account = account
    }

    var isEmailValid: Bool { CredentialRules.isValidEmail(email.text) }
    var showsEmailError: Bool { email.wasEdited && !email.isBlank && !isEmailValid }
    var canSubmit: Bool { isEmailValid && !isSubmitting }

    func submit() async {
        guard canSubmit else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let address = email.text
            try await account.requestPasswordReset(email: address)
            emailSentTo = address
        } catch is CancellationError {
            return
        } catch {
            alert = .authFailure(error)
        }
    }
}

/// Google and Apple sign-in from the welcome screen. Both sign in to Firebase through
/// `AccountService` and enter the app with the same signed-in state as email sign-in.
@MainActor
@Observable
final class FederatedSignInModel {
    private(set) var isWorking = false
    var alert: AlertMessage?
    /// The nonce for the Apple request in flight. Consumed by the first completion so a nonce is
    /// never reused.
    private var appleAttempt: AppleSignInAttempt?

    private let account: AccountService
    private let google: any GoogleSignInProviding
    private let analytics: AnalyticsService
    private let logger = Logger(subsystem: AppLog.subsystem, category: "Auth")

    init(account: AccountService, google: any GoogleSignInProviding, analytics: AnalyticsService = .disabled) {
        self.account = account
        self.google = google
        self.analytics = analytics
    }

    func signInWithGoogle() async -> AccountState? {
        guard !isWorking else { return nil }
        isWorking = true
        defer { isWorking = false }
        do {
            let identity = try await google.signIn()
            let result = try await account.completeGoogleSignIn(identity)
            if let exchangeError = result.exchangeError {
                logger.warning("Tatum Tech Google sign-in failed; continuing without a Tatum Tech session: \(String(describing: exchangeError), privacy: .public)")
            }
            return succeeded(result, method: .google)
        } catch {
            failed(error, provider: .google)
            return nil
        }
    }

    /// Configures the `SignInWithAppleButton` request with a fresh nonce.
    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        do {
            let attempt = try AppleSignInAttempt()
            attempt.configure(request)
            appleAttempt = attempt
        } catch {
            appleAttempt = nil
            request.requestedScopes = [.fullName, .email]
            logger.error("Could not create a Sign in with Apple nonce: \(String(describing: error), privacy: .public)")
        }
    }

    /// Handles the `SignInWithAppleButton` result.
    func completeApple(_ result: Result<ASAuthorization, any Error>) async -> AccountState? {
        let attempt = appleAttempt
        appleAttempt = nil
        let identity = Result<AppleIdentity, any Error> {
            switch result {
            case let .failure(error):
                throw AppleSignInFailure(authorizationError: error)
            case let .success(authorization):
                guard let attempt else { throw AppleSignInFailure.invalidNonce }
                return try AppleIdentity(authorization: authorization, rawNonce: attempt.rawNonce)
            }
        }
        return await finishApple(identity)
    }

    /// Signs in to Firebase with the Apple identity. Separate from `completeApple` so tests can
    /// supply identities without AuthenticationServices.
    func finishApple(_ identity: Result<AppleIdentity, any Error>) async -> AccountState? {
        guard !isWorking else { return nil }
        isWorking = true
        defer { isWorking = false }
        do {
            let result = try await account.completeAppleSignIn(identity.get())
            return succeeded(result, method: .apple)
        } catch {
            failed(error, provider: .apple)
            return nil
        }
    }

    private func succeeded(_ result: FederatedSignInResult, method: AuthMethod) -> AccountState? {
        guard case .signedIn = result.state else {
            alert = .signInFailure(FirebaseAuthFailure.failed("No signed-in state"), provider: method)
            return nil
        }
        analytics.log(result.isNewUser ? .signUp(method: method) : .login(method: method))
        return result.state
    }

    /// Cancellation returns quietly to the welcome screen; anything else is logged, explained in an
    /// alert, and recorded unless the provider is simply not set up in this build.
    private func failed(_ error: any Error, provider: AuthMethod) {
        guard let copy = FederatedSignInCopy(error: error) else { return }
        logger.error("\(provider.rawValue, privacy: .public) sign-in failed: \(String(describing: error), privacy: .public)")
        if copy != .unavailable {
            analytics.recordHandled(error)
        }
        alert = .signInFailure(error, provider: provider)
    }
}
