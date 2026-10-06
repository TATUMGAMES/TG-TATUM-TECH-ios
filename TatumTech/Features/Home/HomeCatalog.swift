import SwiftUI

/// Home page categories, in the order of the Android home pager.
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

/// Feature cards per category. Matches the Android home pager, including which icon each uses.
enum HomeCatalog {
    static func items(for category: HomeCategory) -> [FeatureItem] {
        switch category {
        case .events:
            [
                FeatureItem(id: "upcomingEvents", title: "Upcoming Events", imageName: "upcoming_events", route: .upcomingEvents),
                FeatureItem(id: "scanner", title: "Scanner", imageName: "scanner", route: .pending(.scanner)),
                FeatureItem(id: "partners", title: "Partners", imageName: "partners", route: .partners)
            ]
        case .coding:
            [
                FeatureItem(id: "coding", title: "Coding", imageName: "coding_challenges", route: .pending(.codingChallenges)),
                FeatureItem(id: "aiChallenges", title: "AI & LLMs", imageName: "apps", route: .pending(.aiChallenges)),
                FeatureItem(id: "stats", title: "Stats", imageName: "stats", route: .pending(.stats)),
                FeatureItem(id: "resources", title: "Resources", imageName: "opportunity", route: .pending(.resources))
            ]
        case .community:
            [
                FeatureItem(id: "community", title: "Community", imageName: "community", route: .pending(.community)),
                FeatureItem(id: "donate", title: "Donate", imageName: "donate", route: .pending(.donate))
            ]
        case .career:
            [
                FeatureItem(id: "careers", title: "Apply for Jobs", imageName: "jobs", route: .pending(.careers)),
                FeatureItem(id: "leetCode", title: "Leet Code", imageName: "coding_challenges", route: .pending(.leetCode)),
                FeatureItem(id: "mockInterviews", title: "Mock Interviews", imageName: "career", route: .pending(.mockInterviews))
            ]
        case .games:
            [
                FeatureItem(id: "discoverGames", title: "Discover", imageName: "games", route: .pending(.discoverGames)),
                FeatureItem(id: "gameResources", title: "Resources", imageName: "opportunity", route: .pending(.gameResources))
            ]
        }
    }
}
