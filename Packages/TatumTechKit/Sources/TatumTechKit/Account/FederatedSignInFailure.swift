import Foundation

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

/// Why a Sign in with Apple attempt did not produce a usable Apple credential.
public enum AppleSignInFailure: Error, Equatable, Sendable {
    /// The user closed Apple's sheet. Nothing is shown.
    case cancelled
    /// Apple returned no identity token.
    case missingIdentityToken
    /// No unused nonce exists for this attempt, so the token cannot be verified.
    case invalidNonce
    /// Apple returned something other than an Apple ID credential, or a different Apple ID than
    /// the signed-in one.
    case invalidCredential
    /// Apple returned no authorization code, which token revocation needs.
    case missingAuthorizationCode
    /// Any other AuthenticationServices failure; detail is for logs only.
    case failed(String)
}

/// The kind of message to show for a failed Google or Apple sign-in.
public enum FederatedSignInCopy: Equatable, Sendable {
    case network
    case unavailable
    /// The email already belongs to an account that signs in another way.
    case accountExists
    case disabled
    case failed

    /// The message to show for `error`, or `nil` when the user cancelled and nothing should appear.
    public init?(error: any Error) {
        switch error {
        case is CancellationError:
            return nil
        case let failure as AppleSignInFailure:
            if failure == .cancelled { return nil }
            self = .failed
        case let failure as GoogleSignInFailure:
            guard let copy = failure.copy else { return nil }
            switch copy {
            case .network: self = .network
            case .unavailable: self = .unavailable
            case .failed: self = .failed
            }
        case let failure as FirebaseAuthFailure:
            switch failure {
            case .network: self = .network
            case .unavailable, .providerDisabled: self = .unavailable
            case .accountExistsWithDifferentCredential, .credentialAlreadyInUse: self = .accountExists
            case .userDisabled: self = .disabled
            case .invalidCredential, .invalidNonce, .requiresRecentLogin, .failed: self = .failed
            }
        case let failure as APIError:
            self = failure.isNetworkFailure ? .network : .failed
        default:
            self = .failed
        }
    }
}
