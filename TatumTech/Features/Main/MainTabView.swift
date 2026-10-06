import SwiftUI
import TatumTechKit

/// Signed-in experience: Home, Learn (coding challenges), Timeline, and Stats tabs, with the
/// speaker reminder banner and rating prompt on top.
struct MainTabView: View {
    @Environment(AppModel.self) private var app
    @Environment(AppRouter.self) private var router
    @Environment(MeetingReminderCenter.self) private var reminders

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            tab(.home) { HomeView() }
                .tabItem { Label("Home", systemImage: "house") }

            tab(.learn) { ChallengeQuizView(track: .coding) }
                .tabItem { Label("Learn", systemImage: "face.smiling") }

            tab(.timeline) { TimelineScreen() }
                .tabItem { Label("Timeline", systemImage: "calendar") }

            tab(.stats) { StatsView() }
                .tabItem { Label("Stats", systemImage: "star") }
        }
        .tint(Palette.brandPrimaryStrong)
        .overlay(alignment: .top) { MeetingReminderBannerHost() }
        .sheet(item: $router.ratingTrigger) { trigger in
            RatingView(trigger: trigger)
                .trackScreen("rating_screen")
        }
        .notificationPermissionPrompt(reminders)
        .onChange(of: reminders.pendingDestination, initial: true) { _, destination in
            guard let destination else { return }
            reminders.pendingDestination = nil
            router.ratingTrigger = nil
            router.open(destination)
        }
    }

    private func tab(_ tab: MainTab, @ViewBuilder root: () -> some View) -> some View {
        NavigationStack(path: router.path(for: tab)) {
            root()
                .trackScreen(tab.analyticsRoute)
                .appRouteDestinations()
        }
        .tag(tab)
    }
}
