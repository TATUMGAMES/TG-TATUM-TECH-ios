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

    func refreshLocalUser() async {
        localUser = await local.ensureUser()
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

    /// Signs out everywhere and erases this device's data, keeping only whether the user was
    /// already sent to the App Store to rate the app. Runs to completion even if the calling view
    /// disappears.
    func deleteAccount() async {
        let dependencies = dependencies
        let account = accountService
        dependencies.analytics.log(.deleteAccount)
        await Task {
            await account.signOut()
            await dependencies.googleSignIn.disconnect()
            await dependencies.local.deleteAllData()
            dependencies.contactImages.deleteAll()
        }.value
        reminders.removeAll()
        router.reset()
        localUser = nil
        phase = .signedOut
    }
}

enum AppLog {
    static let subsystem = Bundle.main.bundleIdentifier ?? "com.tatumgames.tatumtech"
}
