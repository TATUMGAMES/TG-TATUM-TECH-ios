import Foundation
import Observation
import OSLog
import TatumTechKit

/// App-wide state: whether someone is signed in, and the services screens use.
@MainActor
@Observable
final class AppModel {
    enum Phase: Equatable {
        case launching
        case signedOut
        case signedIn(AccountSummary)
    }

    private(set) var phase: Phase = .launching
    let dependencies: AppDependencies

    private let logger = Logger(subsystem: AppLog.subsystem, category: "Account")

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    var accountService: AccountService { dependencies.accountService }
    var content: any ContentRepository { dependencies.content }

    /// The name to greet the user with, when one is known.
    var displayName: String? {
        guard case let .signedIn(summary) = phase else { return nil }
        let candidates = [
            summary.user?.firstName,
            summary.user?.username,
            summary.federatedAccount?.displayName
        ]
        return candidates
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }

    /// Restores the stored account. Apple identities the user revoked in Settings are signed out.
    func start() async {
        guard phase == .launching else { return }
        var state = await accountService.state()
        if case let .signedIn(summary) = state,
           summary.method == .apple,
           let userID = summary.federatedAccount?.userID,
           await dependencies.appleCredentials.isRevoked(userID: userID) {
            logger.info("Apple credential no longer authorized; signing out")
            await accountService.signOut()
            state = .signedOut
        }
        apply(state)
    }

    func apply(_ state: AccountState) {
        switch state {
        case .signedOut: phase = .signedOut
        case let .signedIn(summary): phase = .signedIn(summary)
        }
    }

    /// Signs out everywhere and forgets this device's account data. Runs to completion even if
    /// the calling view disappears.
    func deleteAccount() async {
        let google = dependencies.googleSignIn
        let account = accountService
        await Task {
            await google.disconnect()
            await account.signOut()
        }.value
        phase = .signedOut
    }
}

enum AppLog {
    static let subsystem = Bundle.main.bundleIdentifier ?? "com.tatumgames.tatumtech"
}
