import SwiftUI
import TatumTechKit

/// Destinations pushed onto a tab's navigation stack.
enum AppRoute: Hashable {
    case upcomingEvents
    case virtualSpeakers(eventID: String, speakerID: String?)
    case partners
    case challenge(ChallengeTrack)
    case stats
    case achievements
    case timeline
    case resources
    case community
    case donate
    case career
    case games
    case gameDetails(gameID: String)
    case getYourGameDiscovered
    case gamesResources
    case scanner(fromUpcomingEvents: Bool)
    case contactCardEditor
    case myContactCardQR
    case scannedContactPreview
    case profile
    case demographics
    case about(AboutContent)

    /// Screen name reported to analytics, shared across Tatum Tech apps so reports line up.
    /// About and FAQ are not reported.
    var analyticsRoute: String? {
        switch self {
        case .upcomingEvents: "upcoming_events_screen"
        case .virtualSpeakers: "virtual_speakers_screen"
        case .partners: "partners_screen"
        case let .challenge(track): track.routeID
        case .stats: "stats_screen"
        case .achievements: "achievements_screen"
        case .timeline: "my_timeline_screen"
        case .resources: "resources_screen"
        case .community: "community_screen"
        case .donate: "donate_screen"
        case .career: "career_screen"
        case .games: "games_screen"
        case .gameDetails: "game_details_screen"
        case .getYourGameDiscovered: "get_your_game_discovered_screen"
        case .gamesResources: "games_resources_screen"
        case let .scanner(fromUpcomingEvents): fromUpcomingEvents ? "scanner_from_upcoming_events" : "scanner_screen"
        case .contactCardEditor: "contact_card_editor_screen"
        case .myContactCardQR: "my_contact_card_qr_screen"
        case .scannedContactPreview: "scanned_contact_preview"
        case .profile: "user_profile_screen"
        case .demographics: "demographic_screen"
        case .about: nil
        }
    }
}

/// Builds the screen for a route. Lives in one place so every tab navigates the same way.
struct AppRouteDestination: View {
    let route: AppRoute
    @Environment(AppModel.self) private var app

    var body: some View {
        Group {
            switch route {
            case .upcomingEvents:
                UpcomingEventsView(repository: app.content)
            case let .virtualSpeakers(eventID, speakerID):
                VirtualSpeakersView(eventID: eventID, highlightedSpeakerID: speakerID, repository: app.content)
            case .partners:
                PartnersView(repository: app.content)
            case let .challenge(track):
                ChallengeQuizView(track: track)
            case .stats:
                StatsView()
            case .achievements:
                AchievementsView()
            case .timeline:
                TimelineScreen()
            case .resources:
                ResourcesView()
            case .community:
                CommunityView()
            case .donate:
                DonateView()
            case .career:
                CareerView()
            case .games:
                GamesView()
            case let .gameDetails(gameID):
                GameDetailsView(gameID: gameID)
            case .getYourGameDiscovered:
                GetYourGameDiscoveredView()
            case .gamesResources:
                GamesResourcesView()
            case let .scanner(fromUpcomingEvents):
                ScannerView(returnsToUpcomingEvents: fromUpcomingEvents)
            case .contactCardEditor:
                ContactCardEditorView()
            case .myContactCardQR:
                MyContactCardQRView()
            case .scannedContactPreview:
                ScannedContactPreviewView()
            case .profile:
                ProfileView()
            case .demographics:
                DemographicView()
            case let .about(content):
                AboutView(content: content)
            }
        }
        .trackScreen(route.analyticsRoute)
    }
}

extension View {
    /// Registers `AppRoute` destinations on the enclosing `NavigationStack`.
    func appRouteDestinations() -> some View {
        navigationDestination(for: AppRoute.self) { route in
            AppRouteDestination(route: route)
        }
    }

    /// Reports a screen view each time this screen becomes visible.
    func trackScreen(_ route: String?) -> some View {
        modifier(ScreenTracking(route: route))
    }
}

private struct ScreenTracking: ViewModifier {
    let route: String?
    @Environment(AppModel.self) private var app

    func body(content: Content) -> some View {
        content.onAppear {
            if let route { app.dependencies.analytics.navigate(route: route) }
        }
    }
}
