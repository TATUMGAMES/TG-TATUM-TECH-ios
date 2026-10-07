import Foundation
import Observation
import OSLog
import TatumTechKit

/// App-wide state: whether someone is signed in, the local profile, navigation, and the
/// services screens use.
@MainActor
@Observable
final class AppModel {
    enum Phase: Equatable {
        case launching
        case signedOut
        case signedIn(AccountSummary)
    }

    private(set) var phase: Phase = .launching
    /// The on-device profile, created anonymously the first time someone signs in.
    private(set) var localUser: LocalUser?
    let dependencies: AppDependencies
    let router = AppRouter()

    private let logger = Logger(subsystem: AppLog.subsystem, category: "Account")

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    var accountService: AccountService { dependencies.accountService }
    var content: any ContentRepository { dependencies.content }
    var local: LocalRepository { dependencies.local }
    var analytics: AnalyticsService { dependencies.analytics }
    var reminders: MeetingReminderCenter { dependencies.reminders }

    /// Name shown in the Home greeting: the profile's first and last name, or the anonymous id.
    var greetingName: String {
        localUser?.displayNameOrAnonymous ?? ""
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

    /// Signs out an Apple account whose credential was revoked while the app was running.
    func appleCredentialRevoked() async {
        guard case let .signedIn(summary) = phase, summary.method == .apple else { return }
        logger.info("Apple credential revoked; signing out")
        await accountService.signOut()
        reminders.removeAll()
        router.reset()
        phase = .signedOut
    }

    func apply(_ state: AccountState) {
        let wasSignedIn: Bool
        if case .signedIn = phase { wasSignedIn = true } else { wasSignedIn = false }
        switch state {
        case .signedOut:
            phase = .signedOut
        case let .signedIn(summary):
            phase = .signedIn(summary)
            if !wasSignedIn {
                Task { await enterMainExperience() }
            }
        }
    }

    /// Runs each time the signed-in experience opens: prepares the local profile, counts the
    /// open for the rating prompt, and schedules speaker reminders.
    private func enterMainExperience() async {
        await refreshLocalUser()
        let openCount = await local.incrementCounter(CounterKey.appOpenCount)
        let sentToStore = await local.counter(CounterKey.sentToAppStoreForRating) > 0
        if RatingPolicy.shouldPromptForAppOpen(openCount: openCount, hasBeenSentToStore: sentToStore),
           reminders.pendingDestination == nil {
            router.ratingTrigger = .appOpen
        }
        await syncReminders()
    }

    /// Loads the local profile. A profile created now takes its names from the signed-in provider
    /// (Apple sends them only on the first authorization); an existing profile is never changed.
    func refreshLocalUser() async {
        var seed: FederatedAccount?
        if case let .signedIn(summary) = phase { seed = summary.federatedAccount }
        localUser = await local.ensureUser(seedFirstName: seed?.givenName, seedLastName: seed?.familyName)
    }

    /// Fetches upcoming events and schedules reminders for their speaker sessions.
    func syncReminders() async {
        do {
            let events = try await content.upcomingEvents()
            await reminders.sync(events: events)
        } catch {
            logger.notice("Reminder sync skipped: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Whether the user may still be offered the rating prompt.
    func isEligibleForRatingPrompt() async -> Bool {
        await local.counter(CounterKey.sentToAppStoreForRating) == 0
    }

    func markSentToAppStore() async {
        await local.setCounter(CounterKey.sentToAppStoreForRating, to: 1)
    }

    enum AccountDeletionResult: Equatable {
        case deleted
        /// The user closed Apple's sheet; nothing changed.
        case cancelled
        /// Nothing was deleted and the user is still signed in.
        case failed(AlertMessage)
    }

    /// Deletes the Firebase account, signs out everywhere and erases this device's data, keeping
    /// only whether the user was already sent to the App Store to rate the app.
    ///
    /// Sign in with Apple users first authorize again so their Apple tokens can be revoked before
    /// the Firebase user is deleted. Once started, deletion runs to completion even if the calling
    /// view disappears.
    func deleteAccount() async -> AccountDeletionResult {
        let dependencies = dependencies
        let account = accountService
        var appleReauthorization: AppleIdentity?
        if await account.federatedAccount?.provider == .apple {
            do {
                appleReauthorization = try await dependencies.appleReauthorizer.reauthorize()
            } catch {
                guard FederatedSignInCopy(error: error) != nil else { return .cancelled }
                logger.error("Apple reauthorization for account deletion failed: \(String(describing: error), privacy: .public)")
                dependencies.analytics.recordHandled(error)
                return .failed(.accountDeletionFailure(error))
            }
        }
        dependencies.analytics.log(.deleteAccount)
        let logger = logger
        let outcome: Result<Void, any Error> = await Task {
            do {
                if let remoteError = try await account.deleteAccount(appleReauthorization: appleReauthorization) {
                    logger.warning("Firebase user not deleted: \(String(describing: remoteError), privacy: .public)")
                    dependencies.analytics.recordHandled(remoteError)
                }
            } catch {
                return .failure(error)
            }
            await dependencies.googleSignIn.disconnect()
            await dependencies.local.deleteAllData()
            dependencies.contactImages.deleteAll()
            return .success(())
        }.value
        if case let .failure(error) = outcome {
            logger.error("Account deletion failed: \(String(describing: error), privacy: .public)")
            dependencies.analytics.recordHandled(error)
            return .failed(.accountDeletionFailure(error))
        }
        reminders.removeAll()
        router.reset()
        localUser = nil
        phase = .signedOut
        return .deleted
    }
}

enum AppLog {
    static let subsystem = Bundle.main.bundleIdentifier ?? "com.tatumgames.tatumtech"
}
