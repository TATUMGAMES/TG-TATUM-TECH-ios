import Foundation

/// An identity from a sign-in provider (Google or Apple), kept so the user stays signed in even
/// when the Tatum Tech API has not issued a session for it.
public struct FederatedAccount: Codable, Sendable, Equatable {
    public enum Provider: String, Codable, Sendable {
        case google
        case apple
    }

    public var provider: Provider
    /// Stable user identifier from the provider (Google `sub`, Apple user identifier).
    public var userID: String
    public var email: String?
    public var displayName: String?

    public init(provider: Provider, userID: String, email: String? = nil, displayName: String? = nil) {
        self.provider = provider
        self.userID = userID
        self.email = email
        self.displayName = displayName
    }
}

/// What a provider returns after a successful Google sign-in.
public struct GoogleIdentity: Sendable, Equatable {
    public var idToken: String
    public var userID: String
    public var email: String?
    public var displayName: String?

    public init(idToken: String, userID: String, email: String? = nil, displayName: String? = nil) {
        self.idToken = idToken
        self.userID = userID
        self.email = email
        self.displayName = displayName
    }
}

/// What Sign in with Apple returns. Apple sends the name and email only the first time a user
/// authorizes the app.
public struct AppleIdentity: Sendable, Equatable {
    public var userID: String
    public var identityToken: String?
    public var email: String?
    public var displayName: String?

    public init(userID: String, identityToken: String? = nil, email: String? = nil, displayName: String? = nil) {
        self.userID = userID
        self.identityToken = identityToken
        self.email = email
        self.displayName = displayName
    }
}

/// Who is signed in, across every provider.
public enum AccountState: Equatable, Sendable {
    case signedOut
    case signedIn(AccountSummary)
}

public struct AccountSummary: Equatable, Sendable {
    public var method: AuthMethod
    /// Whether the Tatum Tech API issued a session (always true for email; Google sign-in may
    /// continue without one if the API exchange fails; Apple has no API exchange yet).
    public var hasAPISession: Bool
    public var user: TatumTechUser?
    public var federatedAccount: FederatedAccount?

    public init(method: AuthMethod, hasAPISession: Bool, user: TatumTechUser? = nil, federatedAccount: FederatedAccount? = nil) {
        self.method = method
        self.hasAPISession = hasAPISession
        self.user = user
        self.federatedAccount = federatedAccount
    }
}

/// Signs users in and out with every supported provider and reports the combined account state.
///
/// A user is signed in when the Tatum Tech API session exists or a Google/Apple identity is stored,
/// matching the Android app, where a Google (Firebase) user counts as signed in even if the API
/// exchange failed.
public actor AccountService {
    /// Longest wait for the API to accept a Google ID token before continuing without an API session.
    public static let googleExchangeTimeout: Duration = .seconds(10)

    private let sessionManager: SessionManager
    private let federatedStore: SecureValue<FederatedAccount>

    public init(sessionManager: SessionManager, federatedStore: SecureValue<FederatedAccount>) {
        self.sessionManager = sessionManager
        self.federatedStore = federatedStore
    }

    public func state() async -> AccountState {
        let session = await sessionManager.currentSession
        let federated = federatedStore.load()
        if let session {
            return .signedIn(AccountSummary(method: session.authMethod, hasAPISession: true, user: session.user, federatedAccount: federated))
        }
        if let federated {
            let method: AuthMethod = federated.provider == .google ? .google : .apple
            return .signedIn(AccountSummary(method: method, hasAPISession: false, federatedAccount: federated))
        }
        return .signedOut
    }

    // MARK: Email

    public func signIn(email: String, password: String) async throws -> AccountState {
        try await sessionManager.signIn(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
        federatedStore.clear()
        return await state()
    }

    public func signUp(email: String, password: String, confirmPassword: String) async throws -> AccountState {
        try await sessionManager.signUp(
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password,
            confirmPassword: confirmPassword
        )
        federatedStore.clear()
        return await state()
    }

    public func requestPasswordReset(email: String) async throws {
        try await sessionManager.forgotPassword(email: email.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    // MARK: Federated

    /// Stores the Google identity, then exchanges its ID token with the Tatum Tech API.
    ///
    /// The exchange is best effort (at most `googleExchangeTimeout`): if it fails, the user is
    /// still signed in with Google only, as on Android.
    ///
    /// - Returns: The new state and the exchange failure, if any, for logging.
    public func completeGoogleSignIn(_ identity: GoogleIdentity) async throws -> (state: AccountState, exchangeError: (any Error)?) {
        try saveFederated(FederatedAccount(
            provider: .google, userID: identity.userID, email: identity.email, displayName: identity.displayName
        ))
        var exchangeError: (any Error)?
        do {
            let sessionManager = self.sessionManager
            let token = identity.idToken
            _ = try await withTimeout(Self.googleExchangeTimeout) {
                try await sessionManager.signInWithGoogle(idToken: token)
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            exchangeError = error
        }
        return (await state(), exchangeError)
    }

    /// Stores the Apple identity. The Tatum Tech API has no Sign in with Apple endpoint yet, so the
    /// user is signed in with Apple only.
    public func completeAppleSignIn(_ identity: AppleIdentity) throws -> AccountState {
        // Apple only sends name and email on the first authorization; keep what we already have.
        let previous = federatedStore.load().flatMap { $0.provider == .apple && $0.userID == identity.userID ? $0 : nil }
        try saveFederated(FederatedAccount(
            provider: .apple,
            userID: identity.userID,
            email: identity.email ?? previous?.email,
            displayName: identity.displayName ?? previous?.displayName
        ))
        return .signedIn(AccountSummary(method: .apple, hasAPISession: false, federatedAccount: federatedStore.load()))
    }

    public var federatedAccount: FederatedAccount? { federatedStore.load() }

    // MARK: Sign-out

    /// Signs out of the Tatum Tech API (best effort) and forgets every stored identity.
    public func signOut() async {
        await sessionManager.signOut()
        federatedStore.clear()
    }

    private func saveFederated(_ account: FederatedAccount) throws {
        do {
            try federatedStore.save(account)
        } catch {
            throw APIError.unexpected("Account could not be saved: \(error)")
        }
    }
}
