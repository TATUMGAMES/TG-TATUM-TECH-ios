import SwiftUI
import TatumTechKit

/// A dismiss-only alert. Error alerts never show raw error text; see `AlertMessage.authFailure`.
struct AlertMessage: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String

    static func == (lhs: AlertMessage, rhs: AlertMessage) -> Bool { lhs.id == rhs.id }
}

extension AlertMessage {
    static let defaultTitle = String(localized: "Something went wrong")
    static let networkMessage = String(localized: "Can't reach Tatum Tech. Check your connection and try again.")
    static let genericMessage = String(localized: "Something went wrong.")

    /// Explains a failed Tatum Tech auth request using the server's message when it sent one.
    static func authFailure(_ error: any Error) -> AlertMessage {
        AlertMessage(
            title: defaultTitle,
            message: AuthErrorText.message(for: error, networkMessage: networkMessage, genericMessage: genericMessage)
        )
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
        return AlertMessage(title: defaultTitle, message: message)
    }

    /// Explains why the account could not be deleted. The user is still signed in and can retry.
    static func accountDeletionFailure(_ error: any Error) -> AlertMessage {
        let message = FederatedSignInCopy(error: error) == .network
            ? networkMessage
            : String(localized: "We couldn't delete your account. Please try again.")
        return AlertMessage(title: String(localized: "Account not deleted"), message: message)
    }

    static func simple(_ message: String) -> AlertMessage {
        AlertMessage(title: defaultTitle, message: message)
    }
}

extension View {
    /// Presents `message` as an alert with a single OK button.
    func alert(_ message: Binding<AlertMessage?>) -> some View {
        alert(
            message.wrappedValue?.title ?? "",
            isPresented: Binding(
                get: { message.wrappedValue != nil },
                set: { if !$0 { message.wrappedValue = nil } }
            ),
            presenting: message.wrappedValue
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { alert in
            Text(alert.message)
        }
    }
}
