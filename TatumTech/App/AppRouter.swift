import Observation
import SwiftUI
import TatumTechKit

enum MainTab: Hashable, CaseIterable {
    case home, learn, timeline, stats

    /// Screen name reported when the tab's root screen is shown.
    var analyticsRoute: String {
        switch self {
        case .home: "home_pager"
        case .learn: ChallengeTrack.coding.routeID
        case .timeline: "my_timeline_screen"
        case .stats: "stats_screen"
        }
    }
}

extension RatingTrigger: Identifiable {
    public var id: String { rawValue }
}

/// Navigation state for the signed-in experience: the selected tab, each tab's stack, and the
/// rating prompt.
@MainActor
@Observable
final class AppRouter {
    var selectedTab: MainTab = .home
    private var paths: [MainTab: [AppRoute]] = [:]
    /// When set, the rating prompt is shown for this trigger.
    var ratingTrigger: RatingTrigger?
    /// A scanned card waiting for the preview screen.
    private var pendingScan: ContactCardPayload?

    func path(for tab: MainTab) -> Binding<[AppRoute]> {
        Binding(
            get: { self.paths[tab] ?? [] },
            set: { self.paths[tab] = $0 }
        )
    }

    func push(_ route: AppRoute) {
        paths[selectedTab, default: []].append(route)
    }

    func pop() {
        guard paths[selectedTab]?.isEmpty == false else { return }
        paths[selectedTab]?.removeLast()
    }

    /// Pops back to the most recent `route` on the current stack, or one screen if it is absent.
    func pop(to route: AppRoute) {
        guard let stack = paths[selectedTab], let index = stack.lastIndex(of: route) else {
            pop()
            return
        }
        paths[selectedTab] = Array(stack.prefix(through: index))
    }

    /// Leaves the current stack and returns to the Home tab's root.
    func returnHome() {
        paths[selectedTab] = []
        selectedTab = .home
    }

    func open(_ destination: ReminderDestination) {
        push(.virtualSpeakers(eventID: destination.eventID, speakerID: destination.speakerID.isEmpty ? nil : destination.speakerID))
    }

    func open(_ destination: NotificationDestination) {
        switch destination {
        case .codingChallenges: push(.challenge(.coding))
        case .upcomingEvents: push(.upcomingEvents)
        case .career: push(.career)
        case .community: push(.community)
        case .games: push(.games)
        }
    }

    func showScannedCard(_ payload: ContactCardPayload) {
        pendingScan = payload
        push(.scannedContactPreview)
    }

    /// Hands the scanned card to the preview screen once.
    func consumeScannedCard() -> ContactCardPayload? {
        defer { pendingScan = nil }
        return pendingScan
    }

    func reset() {
        selectedTab = .home
        paths = [:]
        ratingTrigger = nil
        pendingScan = nil
    }
}
