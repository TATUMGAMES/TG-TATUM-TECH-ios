import SwiftUI

enum MainTab: Hashable {
    case home, learn, timeline, stats
}

/// Signed-in experience. The four tabs mirror the Android bottom navigation bar.
struct MainTabView: View {
    @State private var selection: MainTab = .home

    var body: some View {
        TabView(selection: $selection) {
            HomeTab()
                .tabItem { Label("Home", systemImage: "house") }
                .tag(MainTab.home)

            PendingTab(feature: .codingChallenges, title: "Learn")
                .tabItem { Label("Learn", systemImage: "face.smiling") }
                .tag(MainTab.learn)

            PendingTab(feature: .timeline, title: "Timeline")
                .tabItem { Label("Timeline", systemImage: "calendar") }
                .tag(MainTab.timeline)

            PendingTab(feature: .stats, title: "Stats")
                .tabItem { Label("Stats", systemImage: "star") }
                .tag(MainTab.stats)
        }
        .tint(Palette.brandPrimaryStrong)
    }
}

private struct HomeTab: View {
    var body: some View {
        NavigationStack {
            HomeView()
                .appRouteDestinations()
        }
    }
}

private struct PendingTab: View {
    let feature: PendingFeature
    let title: LocalizedStringKey

    var body: some View {
        NavigationStack {
            PendingFeatureView(feature: feature)
                .navigationTitle(title)
                .appRouteDestinations()
        }
    }
}
