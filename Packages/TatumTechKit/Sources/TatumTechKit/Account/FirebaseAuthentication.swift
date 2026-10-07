import Foundation

/// A sign-in provider's credential, handed to Firebase Authentication.
public enum FederatedCredential: Sendable, Equatable {
    case google(idToken: String, accessToken: String)
    /// `rawNonce` is the unhashed nonce whose SHA-256 was sent to Apple with the request.
    /// Apple sends the name parts only on the first authorization.
    case apple(idToken: String, rawNonce: String, givenName: String?, familyName: String?)
}

/// The Firebase user a sign-in produced.
public struct FirebaseUserInfo: Sendable, Equatable {
    public var uid: String
    public var email: String?
    public var displayName: String?
    /// Whether this sign-in created the Firebase user.
    public var isNewUser: Bool

    public init(uid: String, email: String? = nil, displayName: String? = nil, isNewUser: Bool = false) {
        self.uid = uid
        self.email = email
        self.displayName = displayName
        self.isNewUser = isNewUser
    }
}

/// A fresh Sign in with Apple authorization, needed to revoke the user's Apple tokens before the
/// Firebase user is deleted.
public struct AppleReauthorization: Sendable, Equatable {
    public var idToken: String
    public var rawNonce: String
    public var authorizationCode: String

    public init(idToken: String, rawNonce: String, authorizationCode: String) {
        self.idToken = idToken
        self.rawNonce = rawNonce
        self.authorizationCode = authorizationCode
    }
}

/// Why Firebase Authentication rejected a request. Detail strings never contain user data.
public enum FirebaseAuthFailure: Error, Equatable, Sendable {
    /// Firebase is not configured in this build (no matching `GoogleService-Info.plist`).
    case unavailable
    case network
    /// The provider token was rejected, expired or malformed.
    case invalidCredential
    /// The Apple identity token does not carry the nonce sent with the request.
    case invalidNonce
    /// Another Firebase user already uses this email with a different provider.
    case accountExistsWithDifferentCredential
    /// The credential already belongs to a different Firebase user.
    case credentialAlreadyInUse
    /// The provider is not enabled in Firebase Authentication.
    case providerDisabled
    case userDisabled
    case requiresRecentLogin
    /// Error domain and code, for logs.
    case failed(String)
}

/// Firebase Authentication as the account layer uses it. The app implements it with the Firebase
/// SDK; tests and UI tests use `InMemoryFirebaseAuthentication`.
public protocol FirebaseAuthenticating: Sendable {
    /// The signed-in Firebase user's ID, if any.
    var currentUserID: String? { get }
    func signIn(with credential: FederatedCredential) async throws -> FirebaseUserInfo
    func signOut()
    /// Deletes the signed-in Firebase user. For Apple users, reauthenticates with the fresh
    /// authorization and revokes the user's Apple tokens first, as Apple requires.
    func deleteCurrentUser(appleReauthorization: AppleReauthorization?) async throws
}

/// Used when Firebase is not configured: every sign-in fails with `.unavailable`.
public struct UnavailableFirebaseAuthentication: FirebaseAuthenticating {
    public init() {}
    public var currentUserID: String? { nil }
    public func signIn(with credential: FederatedCredential) async throws -> FirebaseUserInfo {
        throw FirebaseAuthFailure.unavailable
    }
    public func signOut() {}
    public func deleteCurrentUser(appleReauthorization: AppleReauthorization?) async throws {}
}

/// Firebase Authentication without a network, for tests and UI tests. A provider's ID token stands
/// in for the provider's user identifier, so signing in again with the same token returns the same
/// Firebase user.
public final class InMemoryFirebaseAuthentication: FirebaseAuthenticating, @unchecked Sendable {
    private let lock = NSLock()
    private var current: FirebaseUserInfo?
    private var users: [String: FirebaseUserInfo] = [:]
    private var pendingFailure: FirebaseAuthFailure?
    private var revoked: [String] = []
    private var deleted: [String] = []

    /// - Parameter signedInUserID: A Firebase user that is already signed in.
    public init(signedInUserID: String? = nil) {
        current = signedInUserID.map { FirebaseUserInfo(uid: $0) }
    }

    /// Makes the next sign-in or deletion fail with `failure`.
    public func failNext(with failure: FirebaseAuthFailure) {
        lock.withLock { pendingFailure = failure }
    }

    /// Authorization codes passed for Apple token revocation, in order.
    public var revokedAuthorizationCodes: [String] { lock.withLock { revoked } }

    /// Firebase user IDs that were deleted, in order.
    public var deletedUserIDs: [String] { lock.withLock { deleted } }

    public var currentUserID: String? { lock.withLock { current?.uid } }

    public func signIn(with credential: FederatedCredential) async throws -> FirebaseUserInfo {
        try lock.withLock {
            if let failure = pendingFailure {
                pendingFailure = nil
                throw failure
            }
            let key: String
            var displayName: String?
            switch credential {
            case let .google(idToken, _):
                key = "google:\(idToken)"
            case let .apple(idToken, _, givenName, familyName):
                key = "apple:\(idToken)"
                let name = [givenName, familyName].compactMap { $0 }.joined(separator: " ")
                displayName = name.isEmpty ? nil : name
            }
            if var existing = users[key] {
                existing.isNewUser = false
                current = existing
                return existing
            }
            let user = FirebaseUserInfo(uid: "firebase-\(users.count + 1)", displayName: displayName, isNewUser: true)
            users[key] = user
            current = user
            return user
        }
    }

    public func signOut() {
        lock.withLock { current = nil }
    }

    public func deleteCurrentUser(appleReauthorization: AppleReauthorization?) async throws {
        try lock.withLock {
            if let failure = pendingFailure {
                pendingFailure = nil
                throw failure
            }
            guard let user = current else { return }
            if let appleReauthorization {
                revoked.append(appleReauthorization.authorizationCode)
            }
            deleted.append(user.uid)
            users = users.filter { $0.value.uid != user.uid }
            current = nil
        }
    }
}
