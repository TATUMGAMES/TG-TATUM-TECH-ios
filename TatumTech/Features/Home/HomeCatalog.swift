import SwiftUI

/// Home page categories, in pager order.
enum HomeCategory: String, CaseIterable, Identifiable, Hashable {
    case events, coding, community, career, games

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .events: "Events"
        case .coding: "Coding"
        case .community: "Community"
        case .career: "Career"
        case .games: "Games"
        }
    }
}

/// One tappable card on the home page.
struct FeatureItem: Identifiable, Hashable {
    let id: String
    let title: LocalizedStringKey
    let imageName: String
    let route: AppRoute

    static func == (lhs: FeatureItem, rhs: FeatureItem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// Feature cards per category, with the icon each uses.
enum HomeCatalog {
    static func items(for category: HomeCategory) -> [FeatureItem] {
        switch category {
        case .events:
            [
                FeatureItem(id: "upcomingEvents", title: "Upcoming Events", imageName: "upcoming_events", route: .upcomingEvents),
                FeatureItem(id: "scanner", title: "Scanner", imageName: "scanner", route: .scanner(fromUpcomingEvents: false)),
                FeatureItem(id: "partners", title: "Partners", imageName: "partners", route: .partners)
            ]
        case .coding:
            [
                FeatureItem(id: "coding", title: "Coding", imageName: "coding_challenges", route: .challenge(.coding)),
                FeatureItem(id: "aiChallenges", title: "AI & LLMs", imageName: "apps", route: .challenge(.aiLLM)),
                FeatureItem(id: "stats", title: "Stats", imageName: "stats", route: .stats),
                FeatureItem(id: "resources", title: "Resources", imageName: "opportunity", route: .resources)
            ]
        case .community:
            [
                FeatureItem(id: "community", title: "Community", imageName: "community", route: .community),
                FeatureItem(id: "donate", title: "Donate", imageName: "donate", route: .donate)
            ]
        case .career:
            [
                FeatureItem(id: "careers", title: "Apply for Jobs", imageName: "jobs", route: .career),
                FeatureItem(id: "leetCode", title: "Leet Code", imageName: "coding_challenges", route: .challenge(.leetCode)),
                FeatureItem(id: "mockInterviews", title: "Mock Interviews", imageName: "career", route: .challenge(.mockInterview))
            ]
        case .games:
            [
                FeatureItem(id: "discoverGames", title: "Discover", imageName: "games", route: .games),
                FeatureItem(id: "gameResources", title: "Resources", imageName: "opportunity", route: .gamesResources)
            ]
        }
    }
}
