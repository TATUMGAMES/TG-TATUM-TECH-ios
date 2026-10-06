import Foundation
import UIKit
import TatumTechKit
#if canImport(GoogleSignIn)
@preconcurrency import GoogleSignIn
#endif

/// Native Google sign-in. Produces the Google ID token the Tatum Tech API exchanges at
/// `tatum-tech/signin`. Failures are reported as `GoogleSignInFailure`.
@MainActor
protocol GoogleSignInProviding {
    func signIn() async throws -> GoogleIdentity
    /// Completes the browser round trip. Returns whether the URL belonged to Google sign-in.
    func handle(_ url: URL) -> Bool
    /// Forgets the Google session and revokes the app's access (used by account deletion).
    func disconnect() async
}

/// Used when the GoogleSignIn package or the iOS OAuth client ID is missing: tapping the Google
/// button explains that Google sign-in isn't available.
struct UnavailableGoogleSignIn: GoogleSignInProviding {
    func signIn() async throws -> GoogleIdentity { throw GoogleSignInFailure.unavailable }
    func handle(_ url: URL) -> Bool { false }
    func disconnect() async {}
}

enum GoogleSignInProviderFactory {
    @MainActor
    static func make(bundle: Bundle) -> any GoogleSignInProviding {
        #if canImport(GoogleSignIn)
        if let provider = GoogleSDKSignIn(bundle: bundle) {
            return provider
        }
        #endif
        return UnavailableGoogleSignIn()
    }
}

#if canImport(GoogleSignIn)
/// GoogleSignIn SDK implementation. Requires `GIDClientID` (iOS OAuth client for this bundle ID)
/// and its reversed form registered as a URL scheme; both come from the build's xcconfig.
@MainActor
final class GoogleSDKSignIn: GoogleSignInProviding {
    init?(bundle: Bundle) {
        guard let clientID = Self.clientID(bundle, key: "GIDClientID") else { return nil }
        let serverClientID = Self.clientID(bundle, key: "GIDServerClientID")
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID, serverClientID: serverClientID)
    }

    func signIn() async throws -> GoogleIdentity {
        guard let presenter = UIApplication.shared.topmostViewController else {
            throw GoogleSignInFailure.unavailable
        }
        let result: GIDSignInResult
        do {
            result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
        } catch {
            throw Self.failure(from: error)
        }
        guard let idToken = result.user.idToken?.tokenString, let userID = result.user.userID else {
            throw GoogleSignInFailure.failed("Google returned no ID token")
        }
        return GoogleIdentity(
            idToken: idToken,
            userID: userID,
            email: result.user.profile?.email,
            displayName: result.user.profile?.name
        )
    }

    func handle(_ url: URL) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }

    func disconnect() async {
        do {
            try await GIDSignIn.sharedInstance.disconnect()
        } catch {
            GIDSignIn.sharedInstance.signOut()
        }
    }

    private static func failure(from error: any Error) -> GoogleSignInFailure {
        if let gidError = error as? GIDSignInError, gidError.code == .canceled {
            return .cancelled
        }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return .network
        }
        return .failed("\(nsError.domain) \(nsError.code)")
    }

    /// A configured OAuth client ID, or `nil` when the build setting is blank or unexpanded.
    private static func clientID(_ bundle: Bundle, key: String) -> String? {
        guard let value = (bundle.object(forInfoDictionaryKey: key) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            value.hasSuffix(".apps.googleusercontent.com")
        else { return nil }
        return value
    }
}
#endif

extension UIApplication {
    /// The view controller currently on top of the key window, for presenting system sheets.
    var topmostViewController: UIViewController? {
        let root = connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
        var top = root
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}
