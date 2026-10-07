import Foundation
import Observation

/// Sign-out flow of the Profile screen: confirmation, a single in-flight request, and the failure
/// alert. On success the app leaves the signed-in experience, so nothing here needs resetting.
@MainActor
@Observable
final class ProfileSignOutModel {
    /// The confirmation alert is shown.
    var isConfirming = false
    /// The request is running; the screen shows progress and ignores input.
    private(set) var isSigningOut = false
    /// Why the last attempt failed. Offers "Try Again" when the failure is transient.
    var alert: AlertMessage?

    func requestSignOut() {
        guard !isSigningOut else { return }
        isConfirming = true
    }

    /// Ignored while a sign-out is running, so the request is never sent twice.
    func confirm(using signOut: @MainActor () async -> AppModel.SignOutResult) async {
        guard !isSigningOut else { return }
        isConfirming = false
        alert = nil
        isSigningOut = true
        switch await signOut() {
        case .signedOut:
            break
        case let .failed(message):
            isSigningOut = false
            alert = message
        }
    }
}
