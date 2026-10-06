import Foundation

/// Chooses the user-facing explanation for a failed auth request. Localized copy comes from the
/// caller so this stays free of UI resources.
public enum AuthErrorText {
    /// Server messages beyond this length are cut short so the alert stays readable.
    public static let maxMessageLength = 500

    /// Server-provided HTTP messages are shown as-is (trimmed and length-capped); anything else
    /// falls back to the given copy so no technical detail leaks.
    public static func message(for error: any Error, networkMessage: String, genericMessage: String) -> String {
        guard let apiError = error as? APIError else { return genericMessage }
        switch apiError {
        case .http:
            return apiError.serverMessage.map(capLength) ?? genericMessage
        case .network:
            return networkMessage
        case .decoding, .unexpected:
            return genericMessage
        }
    }

    static func capLength(_ message: String) -> String {
        guard message.count > maxMessageLength else { return message }
        let prefix = message.prefix(maxMessageLength)
        let trimmed = prefix.replacingOccurrences(of: "\\s+$", with: "", options: .regularExpression)
        return trimmed + "…"
    }
}

/// Why a Google sign-in attempt did not produce an identity.
public enum GoogleSignInFailure: Error, Equatable, Sendable {
    /// The user dismissed Google's sheet. Nothing is shown.
    case cancelled
    /// No network connection.
    case network
    /// Google sign-in is not configured or not available on this build or device.
    case unavailable
    /// Any other failure; detail is for logs only.
    case failed(String)

    public enum Copy: Equatable, Sendable {
        case network, unavailable, failed
    }

    /// Which message to show, or `nil` when nothing should be shown.
    public var copy: Copy? {
        switch self {
        case .cancelled: nil
        case .network: .network
        case .unavailable: .unavailable
        case .failed: .failed
        }
    }
}
