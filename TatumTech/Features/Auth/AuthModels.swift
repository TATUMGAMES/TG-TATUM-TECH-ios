import AuthenticationServices
import Foundation
import Observation
import OSLog
import TatumTechKit

/// Field validation shared by the auth forms. Errors appear only after a field loses focus and
/// is not blank, as on Android.
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

    init(account: AccountService) {
        self.account = account
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
            return try await account.signIn(email: email.text, password: password.text)
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

    init(account: AccountService) {
        self.account = account
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
            return try await account.signUp(email: email.text, password: password.text, confirmPassword: confirmation.text)
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

/// Google and Apple sign-in from the welcome screen.
@MainActor
@Observable
final class FederatedSignInModel {
    private(set) var isWorking = false
    var alert: AlertMessage?
    private(set) var appleAttempt = AppleSignInAttempt()

    private let account: AccountService
    private let google: any GoogleSignInProviding
    private let logger = Logger(subsystem: AppLog.subsystem, category: "Auth")

    init(account: AccountService, google: any GoogleSignInProviding) {
        self.account = account
        self.google = google
    }

    func signInWithGoogle() async -> AccountState? {
        guard !isWorking else { return nil }
        isWorking = true
        defer { isWorking = false }
        let identity: GoogleIdentity
        do {
            identity = try await google.signIn()
        } catch let failure as GoogleSignInFailure {
            if case let .failed(detail) = failure {
                logger.error("Google sign-in failed: \(detail, privacy: .public)")
            }
            alert = .googleFailure(failure)
            return nil
        } catch {
            alert = .googleFailure(.failed(String(describing: error)))
            return nil
        }
        do {
            let result = try await account.completeGoogleSignIn(identity)
            if let exchangeError = result.exchangeError {
                logger.warning("Tatum Tech Google sign-in failed; continuing without a Tatum Tech session: \(String(describing: exchangeError), privacy: .public)")
            }
            return result.state
        } catch is CancellationError {
            return nil
        } catch {
            logger.error("Storing the Google account failed: \(String(describing: error), privacy: .public)")
            alert = .googleFailure(.failed("storage"))
            return nil
        }
    }

    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        appleAttempt = AppleSignInAttempt()
        appleAttempt.configure(request)
    }

    func completeApple(_ result: Result<ASAuthorization, any Error>) async -> AccountState? {
        switch result {
        case let .failure(error):
            if !error.isAppleSignInCancellation {
                logger.error("Sign in with Apple failed: \(String(describing: error), privacy: .public)")
                alert = .appleFailure
            }
            return nil
        case let .success(authorization):
            guard let identity = AppleIdentity(authorization: authorization) else {
                alert = .appleFailure
                return nil
            }
            do {
                return try await account.completeAppleSignIn(identity)
            } catch {
                logger.error("Storing the Apple account failed: \(String(describing: error), privacy: .public)")
                alert = .appleFailure
                return nil
            }
        }
    }
}
