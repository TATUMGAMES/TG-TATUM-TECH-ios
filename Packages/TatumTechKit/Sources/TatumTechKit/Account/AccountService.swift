import Foundation

/// An identity from a sign-in provider (Google or Apple) and the Firebase user it signed in as,
/// kept so the user stays signed in even when the Tatum Tech API has not issued a session for it.
public struct FederatedAccount: Codable, Sendable, Equatable {
    public enum Provider: String, Codable, Sendable {
        case google
        case apple
    }

    public var provider: Provider
    /// Stable user identifier from the provider (Google `sub`, Apple user identifier).
    public var userID: String
    /// May be an Apple private relay address (`…@privaterelay.appleid.com`).
    public var email: String?
    public var displayName: String?
    public var givenName: String?
    public var familyName: String?
    /// The Firebase user this identity signed in as. Accounts stored before Firebase sign-in have none.
    public var firebaseUID: String?

    public init(
        provider: Provider,
        userID: String,
        email: String? = nil,
        displayName: String? = nil,
        givenName: String? = nil,
        familyName: String? = nil,
        firebaseUID: String? = nil
    ) {
        self.provider = provider
        self.userID = userID
        self.email = email
        self.displayName = displayName
        self.givenName = givenName
        self.familyName = familyName
        self.firebaseUID = firebaseUID
    }
}

/// What a provider returns after a successful Google sign-in.
public struct GoogleIdentity: Sendable, Equatable {
    public var idToken: String
    public var accessToken: String
    public var userID: String
    public var email: String?
    public var displayName: String?

    public init(idToken: String, accessToken: String = "", userID: String, email: String? = nil, displayName: String? = nil) {
        self.idToken = idToken
        self.accessToken = accessToken
        self.userID = userID
        self.email = email
        self.displayName = displayName
    }
}

/// What Sign in with Apple returns. Apple sends the name and email only the first time a user
/// authorizes the app; the email may be a private relay address.
public struct AppleIdentity: Sendable, Equatable {
    public var userID: String
    public var identityToken: String?
    /// The unhashed nonce for the request that produced this identity.
    public var rawNonce: String?
    public var authorizationCode: String?
    public var email: String?
    public var displayName: String?
    public var givenName: String?
    public var familyName: String?

    public init(
        userID: String,
        identityToken: String? = nil,
        rawNonce: String? = nil,
        authorizationCode: String? = nil,
        email: String? = nil,
        displayName: String? = nil,
        givenName: String? = nil,
        familyName: String? = nil
    ) {
        self.userID = userID
        self.identityToken = identityToken
        self.rawNonce = rawNonce
        self.authorizationCode = authorizationCode
        self.email = email
        self.displayName = displayName
        self.givenName = givenName
        self.familyName = familyName
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

/// The outcome of a Google or Apple sign-in.
public struct FederatedSignInResult: Sendable {
    public var state: AccountState
    /// Whether Firebase created a new user for this sign-in.
    public var isNewUser: Bool
    /// Why the Tatum Tech API exchange failed, if it did (Google only), for logging.
    public var exchangeError: (any Error)?
}

/// Signs users in and out with every supported provider and reports the combined account state.
///
/// Google and Apple both sign in to Firebase Authentication first; the resulting Firebase user is
/// stored with the provider identity. A user is signed in when the Tatum Tech API session exists,
/// or when a stored Google/Apple identity matches the signed-in Firebase user.
public actor AccountService {
    /// Longest wait for the API to accept a Google ID token before continuing without an API session.
    public static let googleExchangeTimeout: Duration = .seconds(10)

    private let sessionManager: SessionManager
    private let federatedStore: SecureValue<FederatedAccount>
    private let firebase: any FirebaseAuthenticating

    public init(
        sessionManager: SessionManager,
        federatedStore: SecureValue<FederatedAccount>,
        firebase: any FirebaseAuthenticating
    ) {
        self.sessionManager = sessionManager
        self.federatedStore = federatedStore
        self.firebase = firebase
    }

    public func state() async -> AccountState {
        let session = await sessionManager.currentSession
        let federated = federatedStore.load()
        if let session {
            return .signedIn(AccountSummary(method: session.authMethod, hasAPISession: true, user: session.user, federatedAccount: federated))
        }
        if let federated, let uid = federated.firebaseUID, uid == firebase.currentUserID {
            let method: AuthMethod = federated.provider == .google ? .google : .apple
            return .signedIn(AccountSummary(method: method, hasAPISession: false, federatedAccount: federated))
        }
        return .signedOut
    }

    // MARK: Email

    public func signIn(email: String, password: String) async throws -> AccountState {
        try await sessionManager.signIn(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
        forgetFederatedIdentity()
        return await state()
    }

    public func signUp(email: String, password: String, confirmPassword: String) async throws -> AccountState {
        try await sessionManager.signUp(
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password,
            confirmPassword: confirmPassword
        )
        forgetFederatedIdentity()
        return await state()
    }

    public func requestPasswordReset(email: String) async throws {
        try await sessionManager.forgotPassword(email: email.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    // MARK: Federated

    /// Signs in to Firebase with the Google credential, stores the identity, then exchanges the
    /// ID token with the Tatum Tech API.
    ///
    /// A Firebase failure is thrown and nothing is stored. The API exchange is best effort (at
    /// most `googleExchangeTimeout`): if it fails, the user is still signed in with Google.
    public func completeGoogleSignIn(_ identity: GoogleIdentity) async throws -> FederatedSignInResult {
        let firebaseUser = try await firebase.signIn(with: .google(idToken: identity.idToken, accessToken: identity.accessToken))
        try saveFederated(FederatedAccount(
            provider: .google,
            userID: identity.userID,
            email: identity.email ?? firebaseUser.email,
            displayName: identity.displayName ?? firebaseUser.displayName,
            firebaseUID: firebaseUser.uid
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
        return FederatedSignInResult(state: await state(), isNewUser: firebaseUser.isNewUser, exchangeError: exchangeError)
    }

    /// Signs in to Firebase with the Apple credential and stores the identity. The Tatum Tech API
    /// has no Sign in with Apple endpoint yet, so there is no API session.
    ///
    /// Apple sends the name and email only on the first authorization, so values already known for
    /// this Apple ID (stored here, or kept by Firebase from the first sign-in) are never replaced
    /// with empty ones.
    public func completeAppleSignIn(_ identity: AppleIdentity) async throws -> FederatedSignInResult {
        guard let token = identity.identityToken?.nonBlank else { throw AppleSignInFailure.missingIdentityToken }
        guard let nonce = identity.rawNonce?.nonBlank else { throw AppleSignInFailure.invalidNonce }
        let firebaseUser = try await firebase.signIn(with: .apple(
            idToken: token,
            rawNonce: nonce,
            givenName: identity.givenName?.nonBlank,
            familyName: identity.familyName?.nonBlank
        ))
        let previous = federatedStore.load().flatMap { $0.provider == .apple && $0.userID == identity.userID ? $0 : nil }
        try saveFederated(FederatedAccount(
            provider: .apple,
            userID: identity.userID,
            email: identity.email?.nonBlank ?? previous?.email ?? firebaseUser.email,
            displayName: identity.displayName?.nonBlank ?? previous?.displayName ?? firebaseUser.displayName,
            givenName: identity.givenName?.nonBlank ?? previous?.givenName,
            familyName: identity.familyName?.nonBlank ?? previous?.familyName,
            firebaseUID: firebaseUser.uid
        ))
        return FederatedSignInResult(state: await state(), isNewUser: firebaseUser.isNewUser, exchangeError: nil)
    }

    public var federatedAccount: FederatedAccount? { federatedStore.load() }

    // MARK: Sign-out and deletion

    /// Signs out of the Tatum Tech API (best effort) and Firebase, and forgets every stored identity.
    public func signOut() async {
        await sessionManager.signOut()
        forgetFederatedIdentity()
    }

    /// Signs out of the Tatum Tech API and, once the server confirms (or there is no API session),
    /// out of Firebase, forgetting every stored identity. A failure is thrown with nothing cleared,
    /// so the user stays signed in and can retry. The account and its data are kept.
    public func signOutOrFail() async throws {
        try await sessionManager.signOutOrFail()
        forgetFederatedIdentity()
    }

    /// Deletes the signed-in user's Firebase account, then signs out everywhere.
    ///
    /// Apple users must pass a fresh authorization for the same Apple ID: their Apple tokens are
    /// revoked before the Firebase user is deleted, and any failure is thrown with the user still
    /// signed in so they can retry. For Google users the Firebase deletion is best effort and its
    /// failure is returned for logging.
    @discardableResult
    public func deleteAccount(appleReauthorization: AppleIdentity? = nil) async throws -> (any Error)? {
        let federated = federatedStore.load()
        var remoteError: (any Error)?
        switch federated?.provider {
        case .apple?:
            guard let identity = appleReauthorization, identity.userID == federated?.userID else {
                throw AppleSignInFailure.invalidCredential
            }
            guard let token = identity.identityToken?.nonBlank else { throw AppleSignInFailure.missingIdentityToken }
            guard let nonce = identity.rawNonce?.nonBlank else { throw AppleSignInFailure.invalidNonce }
            guard let code = identity.authorizationCode?.nonBlank else { throw AppleSignInFailure.missingAuthorizationCode }
            try await firebase.deleteCurrentUser(appleReauthorization: AppleReauthorization(
                idToken: token, rawNonce: nonce, authorizationCode: code
            ))
        case .google?:
            do {
                try await firebase.deleteCurrentUser(appleReauthorization: nil)
            } catch {
                remoteError = error
            }
        case nil:
            break
        }
        await signOut()
        return remoteError
    }

    private func forgetFederatedIdentity() {
        firebase.signOut()
        federatedStore.clear()
    }

    private func saveFederated(_ account: FederatedAccount) throws {
        do {
            try federatedStore.save(account)
        } catch {
            firebase.signOut()
            throw APIError.unexpected("Account could not be saved: \(error)")
        }
    }
}
