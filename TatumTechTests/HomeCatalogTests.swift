import Testing
import UIKit
@testable import TatumTech

@Suite("Home catalog")
struct HomeCatalogTests {
    @Test func categoriesMatchTheAndroidPagerOrder() {
        #expect(HomeCategory.allCases == [.events, .coding, .community, .career, .games])
    }

    @Test func eachCategoryHasTheAndroidCards() {
        #expect(HomeCatalog.items(for: .events).map(\.id) == ["upcomingEvents", "scanner", "partners"])
        #expect(HomeCatalog.items(for: .coding).map(\.id) == ["coding", "aiChallenges", "stats", "resources"])
        #expect(HomeCatalog.items(for: .community).map(\.id) == ["community", "donate"])
        #expect(HomeCatalog.items(for: .career).map(\.id) == ["careers", "leetCode", "mockInterviews"])
        #expect(HomeCatalog.items(for: .games).map(\.id) == ["discoverGames", "gameResources"])
    }

    @Test func implementedScreensAreRoutedDirectly() {
        let events = HomeCatalog.items(for: .events)
        #expect(events.first { $0.id == "upcomingEvents" }?.route == .upcomingEvents)
        #expect(events.first { $0.id == "partners" }?.route == .partners)
    }

    @Test func everyCardIconIsBundled() {
        for category in HomeCategory.allCases {
            for item in HomeCatalog.items(for: category) {
                #expect(UIImage(named: item.imageName) != nil, "Missing image \(item.imageName)")
            }
        }
    }
}
