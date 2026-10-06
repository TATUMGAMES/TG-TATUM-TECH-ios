import AuthenticationServices
import CryptoKit
import Foundation
import TatumTechKit

/// Checks whether a stored Sign in with Apple identity is still authorized.
protocol AppleCredentialStateChecking: Sendable {
    func isRevoked(userID: String) async -> Bool
}

struct AppleIDCredentialStateChecker: AppleCredentialStateChecking {
    func isRevoked(userID: String) async -> Bool {
        do {
            let state = try await ASAuthorizationAppleIDProvider().credentialState(forUserID: userID)
            return state == .revoked || state == .notFound
        } catch {
            // Offline or transient failure: keep the user signed in and check again next launch.
            return false
        }
    }
}

/// Always authorized; used by UI tests and previews.
struct AuthorizedAppleCredentials: AppleCredentialStateChecking {
    func isRevoked(userID: String) async -> Bool { false }
}

/// One Sign in with Apple attempt. The SHA-256 of `rawNonce` goes in the request so a future
/// backend exchange can verify the identity token was minted for this attempt.
struct AppleSignInAttempt {
    let rawNonce: String

    init(rawNonce: String = AppleSignInAttempt.randomNonce()) {
        self.rawNonce = rawNonce
    }

    var hashedNonce: String {
        SHA256.hash(data: Data(rawNonce.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    func configure(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
        request.nonce = hashedNonce
    }

    static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var generator = SystemRandomNumberGenerator()
        return String((0..<length).map { _ in charset.randomElement(using: &generator)! })
    }
}

extension AppleIdentity {
    /// Apple sends the name and email only on the first authorization; later ones carry just the
    /// user identifier.
    init?(authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return nil }
        let name = credential.fullName
            .map { PersonNameComponentsFormatter.localizedString(from: $0, style: .default) }?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.init(
            userID: credential.user,
            identityToken: credential.identityToken.flatMap { String(data: $0, encoding: .utf8) },
            email: credential.email,
            displayName: (name?.isEmpty ?? true) ? nil : name
        )
    }
}

extension Error {
    /// Whether the user closed the Sign in with Apple sheet.
    var isAppleSignInCancellation: Bool {
        (self as? ASAuthorizationError)?.code == .canceled
    }
}
