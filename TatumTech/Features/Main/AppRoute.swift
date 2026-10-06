import SwiftUI

/// Destinations pushed onto a tab's navigation stack.
enum AppRoute: Hashable {
    case upcomingEvents
    case virtualSpeakers(eventID: String)
    case partners
    case pending(PendingFeature)
}

/// Builds the screen for a route. Lives in one place so every tab navigates the same way.
struct AppRouteDestination: View {
    let route: AppRoute
    @Environment(AppModel.self) private var app

    var body: some View {
        switch route {
        case .upcomingEvents:
            UpcomingEventsView(repository: app.content)
        case let .virtualSpeakers(eventID):
            VirtualSpeakersView(eventID: eventID, repository: app.content)
        case .partners:
            PartnersView(repository: app.content)
        case let .pending(feature):
            PendingFeatureView(feature: feature)
        }
    }
}

extension View {
    /// Registers `AppRoute` destinations on the enclosing `NavigationStack`.
    func appRouteDestinations() -> some View {
        navigationDestination(for: AppRoute.self) { route in
            AppRouteDestination(route: route)
        }
    }
}
