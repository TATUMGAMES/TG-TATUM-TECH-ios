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

    /// Explains a failed Google sign-in, or `nil` when the user cancelled.
    static func googleFailure(_ failure: GoogleSignInFailure) -> AlertMessage? {
        guard let copy = failure.copy else { return nil }
        let message = switch copy {
        case .network: networkMessage
        case .unavailable: String(localized: "Google sign-in isn't available right now. Please try again, or sign in with your email.")
        case .failed: String(localized: "We couldn't sign you in with Google. Please try again, or sign in with your email.")
        }
        return AlertMessage(title: defaultTitle, message: message)
    }

    static let appleFailure = AlertMessage(
        title: defaultTitle,
        message: String(localized: "We couldn't sign you in with Apple. Please try again, or sign in with your email.")
    )

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
