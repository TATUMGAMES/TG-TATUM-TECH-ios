import Testing
import UIKit
@testable import TatumTech

@Suite("Home catalog")
struct HomeCatalogTests {
    @Test func categoriesAreInPagerOrder() {
        #expect(HomeCategory.allCases == [.events, .coding, .community, .career, .games])
    }

    @Test func eachCategoryHasItsCards() {
        #expect(HomeCatalog.items(for: .events).map(\.id) == ["upcomingEvents", "scanner", "partners"])
        #expect(HomeCatalog.items(for: .coding).map(\.id) == ["coding", "aiChallenges", "stats", "resources"])
        #expect(HomeCatalog.items(for: .community).map(\.id) == ["community", "donate"])
        #expect(HomeCatalog.items(for: .career).map(\.id) == ["careers", "leetCode", "mockInterviews"])
        #expect(HomeCatalog.items(for: .games).map(\.id) == ["discoverGames", "gameResources"])
    }

    @Test func everyCardOpensItsScreen() {
        let routes = Dictionary(
            uniqueKeysWithValues: HomeCategory.allCases.flatMap(HomeCatalog.items(for:)).map { ($0.id, $0.route) }
        )
        #expect(routes == [
            "upcomingEvents": .upcomingEvents,
            "scanner": .scanner(fromUpcomingEvents: false),
            "partners": .partners,
            "coding": .challenge(.coding),
            "aiChallenges": .challenge(.aiLLM),
            "stats": .stats,
            "resources": .resources,
            "community": .community,
            "donate": .donate,
            "careers": .career,
            "leetCode": .challenge(.leetCode),
            "mockInterviews": .challenge(.mockInterview),
            "discoverGames": .games,
            "gameResources": .gamesResources
        ])
    }

    @Test func screenNamesMatchTheSharedAnalyticsRoutes() {
        #expect(AppRoute.scanner(fromUpcomingEvents: true).analyticsRoute == "scanner_from_upcoming_events")
        #expect(AppRoute.scanner(fromUpcomingEvents: false).analyticsRoute == "scanner_screen")
        #expect(AppRoute.timeline.analyticsRoute == "my_timeline_screen")
        #expect(AppRoute.profile.analyticsRoute == "user_profile_screen")
        #expect(AppRoute.about(.faq).analyticsRoute == nil)
    }

    @Test func everyCardIconIsBundled() {
        for category in HomeCategory.allCases {
            for item in HomeCatalog.items(for: category) {
                #expect(UIImage(named: item.imageName) != nil, "Missing image \(item.imageName)")
            }
        }
    }
}
