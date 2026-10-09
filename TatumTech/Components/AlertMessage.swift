import SwiftUI
import TatumTechKit

/// An alert with OK, or "Try Again" and Cancel when `canRetry` is set and the screen supplies a
/// retry action. Error alerts never show raw error text; see `AlertMessage.apiFailure`.
struct AlertMessage: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
    /// The failure is transient, so repeating the request may succeed. Never retried automatically.
    var canRetry = false

    static func == (lhs: AlertMessage, rhs: AlertMessage) -> Bool { lhs.id == rhs.id }
}

extension AlertMessage {
    static let defaultTitle = String(localized: "We’ve Encountered an Issue")
    static let networkMessage = String(localized: "Can't reach Tatum Tech. Check your connection and try again.")

    /// Explains a failed Tatum Tech request. Request-specific failures are titled after the
    /// operation; connectivity and service failures use `defaultTitle`.
    static func apiFailure(_ error: any Error, operation: APIOperation) -> AlertMessage {
        let presentation = APIErrorPresentation(error: error, operation: operation)
        return AlertMessage(
            title: presentation.usesOperationTitle ? title(for: operation) : defaultTitle,
            message: presentation.serverMessage ?? message(for: presentation.message),
            canRetry: presentation.canRetry
        )
    }

    static func title(for operation: APIOperation) -> String {
        switch operation {
        case .signIn: String(localized: "Unable to Sign In")
        case .signUp: String(localized: "Unable to Create Your Account")
        case .forgotPassword: String(localized: "Unable to Send Reset Email")
        case .loadContent: String(localized: "Unable to Load Content")
        case .signOut: String(localized: "Unable to Sign Out")
        case .updateProfile: String(localized: "Unable to Save Profile")
        }
    }

    static func message(for message: APIErrorPresentation.Message) -> String {
        switch message {
        case .network: networkMessage
        case .timeout: String(localized: "Tatum Tech is taking too long to respond. Please try again.")
        case .badRequest: String(localized: "Some of the information couldn't be accepted. Please check it and try again.")
        case .credentialsRejected: String(localized: "We couldn't verify those details. Please check them and try again.")
        case .sessionExpired: String(localized: "Your session has expired. Please sign in again.")
        case .forbidden: String(localized: "You don't have permission to do that.")
        case .notFound: String(localized: "We couldn't find what you were looking for.")
        case .conflict: String(localized: "That conflicts with existing information. Please review it and try again.")
        case .rateLimited: String(localized: "Too many attempts. Please wait a moment and try again.")
        case .server: String(localized: "Tatum Tech is having trouble right now. Please try again in a few minutes.")
        case .service: String(localized: "We’re having trouble connecting to Tatum Tech right now. Please try again later.")
        case .accountExists: String(localized: "An account with this email already exists. Try signing in instead.")
        case .invalidEmail: String(localized: "Input a valid email address.")
        case .invalidPassword: String(localized: "Password must be at minimum 6 characters with 1 uppercase letter and 1 special character.")
        case .passwordsDoNotMatch: String(localized: "Passwords do not match.")
        case .wrongEmailOrPassword: String(localized: "The email or password is incorrect.")
        }
    }

    /// Explains a failed Google or Apple sign-in, or `nil` when the user cancelled.
    static func signInFailure(_ error: any Error, provider: AuthMethod) -> AlertMessage? {
        guard let copy = FederatedSignInCopy(error: error) else { return nil }
        let apple = provider == .apple
        let message = switch copy {
        case .network:
            networkMessage
        case .unavailable:
            apple
                ? String(localized: "Sign in with Apple isn't available right now. Please try again later, or sign in with your email.")
                : String(localized: "Google sign-in isn't available right now. Please try again, or sign in with your email.")
        case .accountExists:
            String(localized: "An account with this email already uses a different sign-in method. Please sign in the way you did before.")
        case .disabled:
            String(localized: "This account has been disabled.")
        case .failed:
            apple
                ? String(localized: "We couldn't sign you in with Apple. Please try again, or sign in with your email.")
                : String(localized: "We couldn't sign you in with Google. Please try again, or sign in with your email.")
        }
        return AlertMessage(title: title(for: .signIn), message: message)
    }

    /// Explains why the account could not be deleted. The user is still signed in and can retry.
    static func accountDeletionFailure(_ error: any Error) -> AlertMessage {
        let message = FederatedSignInCopy(error: error) == .network
            ? networkMessage
            : String(localized: "We couldn't delete your account. Please try again.")
        return AlertMessage(title: String(localized: "Account Not Deleted"), message: message)
    }

    static func simple(_ message: String) -> AlertMessage {
        AlertMessage(title: defaultTitle, message: message)
    }
}

extension View {
    /// Presents `message` as an alert. Offers "Try Again" and Cancel when the message allows a
    /// retry and `retry` is given; otherwise a single OK button.
    func alert(_ message: Binding<AlertMessage?>, retry: (@MainActor () -> Void)? = nil) -> some View {
        alert(
            message.wrappedValue?.title ?? "",
            isPresented: Binding(
                get: { message.wrappedValue != nil },
                set: { if !$0 { message.wrappedValue = nil } }
            ),
            presenting: message.wrappedValue
        ) { alert in
            if alert.canRetry, let retry {
                Button("Try Again", action: retry)
                Button("Cancel", role: .cancel) {}
            } else {
                Button("OK", role: .cancel) {}
            }
        } message: { alert in
            Text(alert.message)
        }
    }
}
