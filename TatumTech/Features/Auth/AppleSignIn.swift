import AuthenticationServices
import CryptoKit
import Foundation
import Security
import TatumTechKit
import UIKit

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

/// One Sign in with Apple request. Apple receives the SHA-256 of `rawNonce`; Firebase receives
/// `rawNonce` and checks that the identity token carries its hash. A new attempt, with a new nonce,
/// is made for every request.
struct AppleSignInAttempt {
    let rawNonce: String

    /// Fails only if the system random number generator fails.
    init() throws {
        rawNonce = try Self.randomNonce()
    }

    init(rawNonce: String) {
        self.rawNonce = rawNonce
    }

    var hashedNonce: String {
        SHA256.hash(data: Data(rawNonce.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    func configure(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
        request.nonce = hashedNonce
    }

    /// `length` characters drawn from cryptographically secure random bytes.
    static func randomNonce(length: Int = 32) throws -> String {
        precondition(length > 0)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var bytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            throw AppleSignInFailure.failed("SecRandomCopyBytes \(status)")
        }
        return String(bytes.map { charset[Int($0) % charset.count] })
    }
}

extension AppleIdentity {
    /// Apple sends the name and email only on the first authorization; later ones carry just the
    /// user identifier and tokens.
    init(authorization: ASAuthorization, rawNonce: String) throws {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw AppleSignInFailure.invalidCredential
        }
        guard let token = credential.identityToken.flatMap({ String(data: $0, encoding: .utf8) }), !token.isEmpty else {
            throw AppleSignInFailure.missingIdentityToken
        }
        let name = credential.fullName
            .map { PersonNameComponentsFormatter.localizedString(from: $0, style: .default) }?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.init(
            userID: credential.user,
            identityToken: token,
            rawNonce: rawNonce,
            authorizationCode: credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) },
            email: credential.email,
            displayName: (name?.isEmpty ?? true) ? nil : name,
            givenName: credential.fullName?.givenName,
            familyName: credential.fullName?.familyName
        )
    }
}

extension AppleSignInFailure {
    /// Translates an AuthenticationServices error. Closing the sheet is a cancellation, not a failure.
    init(authorizationError error: any Error) {
        guard let authorizationError = error as? ASAuthorizationError else {
            let nsError = error as NSError
            self = .failed("\(nsError.domain) \(nsError.code)")
            return
        }
        switch authorizationError.code {
        case .canceled:
            self = .cancelled
        case .invalidResponse:
            self = .invalidCredential
        default:
            self = .failed("ASAuthorizationError \(authorizationError.code.rawValue)")
        }
    }
}

/// Asks the signed-in Apple user to authorize again, for account deletion.
@MainActor
protocol AppleReauthorizing {
    /// - Throws: `AppleSignInFailure.cancelled` when the user closes Apple's sheet.
    func reauthorize() async throws -> AppleIdentity
}

/// Runs a Sign in with Apple request outside a `SignInWithAppleButton`.
@MainActor
final class AppleAuthorizationRunner: NSObject, AppleReauthorizing {
    private var continuation: CheckedContinuation<ASAuthorization, any Error>?
    private var controller: ASAuthorizationController?

    func reauthorize() async throws -> AppleIdentity {
        guard continuation == nil else { throw AppleSignInFailure.failed("A request is already running") }
        let attempt = try AppleSignInAttempt()
        let request = ASAuthorizationAppleIDProvider().createRequest()
        attempt.configure(request)
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        self.controller = controller
        defer { self.controller = nil }
        let authorization = try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            controller.performRequests()
        }
        return try AppleIdentity(authorization: authorization, rawNonce: attempt.rawNonce)
    }

    private func finish(_ result: Result<ASAuthorization, any Error>) {
        continuation?.resume(with: result)
        continuation = nil
    }
}

extension AppleAuthorizationRunner: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        MainActor.assumeIsolated { finish(.success(authorization)) }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: any Error) {
        MainActor.assumeIsolated { finish(.failure(AppleSignInFailure(authorizationError: error))) }
    }
}

extension AppleAuthorizationRunner: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
        }
    }
}

/// Re-authorizes as the stored UI-test Apple user without showing Apple's sheet.
struct UITestAppleReauthorizer: AppleReauthorizing {
    let userID: String

    func reauthorize() async throws -> AppleIdentity {
        AppleIdentity(userID: userID, identityToken: "ui-test-token", rawNonce: "ui-test-nonce", authorizationCode: "ui-test-code")
    }
}
