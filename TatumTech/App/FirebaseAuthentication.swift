import Foundation
import TatumTechKit
#if canImport(FirebaseAuth)
@preconcurrency import FirebaseAuth
#endif

enum FirebaseAuthenticationFactory {
    /// Firebase Authentication when Firebase started for this build, otherwise a stand-in that
    /// reports Google and Apple sign-in as unavailable.
    static func make(isFirebaseConfigured: Bool) -> any FirebaseAuthenticating {
        #if canImport(FirebaseAuth)
        if isFirebaseConfigured {
            return FirebaseSDKAuthentication()
        }
        #endif
        return UnavailableFirebaseAuthentication()
    }
}

#if canImport(FirebaseAuth)
/// Firebase Authentication for Google and Apple credentials. Errors are translated to
/// `FirebaseAuthFailure` without user data.
struct FirebaseSDKAuthentication: FirebaseAuthenticating {
    var currentUserID: String? { Auth.auth().currentUser?.uid }

    func signIn(with credential: FederatedCredential) async throws -> FirebaseUserInfo {
        do {
            let result = try await Auth.auth().signIn(with: Self.authCredential(credential))
            return FirebaseUserInfo(
                uid: result.user.uid,
                email: result.user.email,
                displayName: result.user.displayName,
                isNewUser: result.additionalUserInfo?.isNewUser ?? false
            )
        } catch {
            throw Self.failure(from: error)
        }
    }

    func signOut() {
        try? Auth.auth().signOut()
    }

    func deleteCurrentUser(appleReauthorization: AppleReauthorization?) async throws {
        guard let user = Auth.auth().currentUser else { return }
        do {
            if let appleReauthorization {
                let credential = OAuthProvider.appleCredential(
                    withIDToken: appleReauthorization.idToken,
                    rawNonce: appleReauthorization.rawNonce,
                    fullName: nil
                )
                _ = try await user.reauthenticate(with: credential)
                try await Auth.auth().revokeToken(withAuthorizationCode: appleReauthorization.authorizationCode)
            }
            try await user.delete()
        } catch {
            throw Self.failure(from: error)
        }
    }

    private static func authCredential(_ credential: FederatedCredential) -> AuthCredential {
        switch credential {
        case let .google(idToken, accessToken):
            return GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
        case let .apple(idToken, rawNonce, givenName, familyName):
            var fullName: PersonNameComponents?
            if givenName != nil || familyName != nil {
                var name = PersonNameComponents()
                name.givenName = givenName
                name.familyName = familyName
                fullName = name
            }
            return OAuthProvider.appleCredential(withIDToken: idToken, rawNonce: rawNonce, fullName: fullName)
        }
    }

    private static func failure(from error: any Error) -> FirebaseAuthFailure {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return .network
        }
        guard nsError.domain == "FIRAuthErrorDomain", let code = AuthErrorCode(rawValue: nsError.code) else {
            return .failed("\(nsError.domain) \(nsError.code)")
        }
        switch code {
        case .networkError, .webNetworkRequestFailed:
            return .network
        case .invalidCredential, .invalidUserToken, .userTokenExpired, .userMismatch:
            return .invalidCredential
        case .missingOrInvalidNonce:
            return .invalidNonce
        case .accountExistsWithDifferentCredential:
            return .accountExistsWithDifferentCredential
        case .credentialAlreadyInUse:
            return .credentialAlreadyInUse
        case .operationNotAllowed:
            return .providerDisabled
        case .userDisabled:
            return .userDisabled
        case .requiresRecentLogin:
            return .requiresRecentLogin
        default:
            return .failed("\(nsError.domain) \(nsError.code)")
        }
    }
}
#endif
