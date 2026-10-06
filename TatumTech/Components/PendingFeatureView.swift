import SwiftUI

/// Destinations that exist on Android and have not been built for iOS yet. Each one is tracked in
/// docs/IOS_FEATURE_PARITY.md; remove a case once its screen ships.
enum PendingFeature: String, CaseIterable, Hashable, Identifiable {
    case scanner
    case codingChallenges
    case aiChallenges
    case stats
    case resources
    case community
    case donate
    case careers
    case leetCode
    case mockInterviews
    case discoverGames
    case gameResources
    case timeline
    case profile
    case demographics
    case about
    case faq

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .scanner: "Scanner"
        case .codingChallenges: "Coding"
        case .aiChallenges: "AI & LLMs"
        case .stats: "Stats"
        case .resources: "Resources"
        case .community: "Community"
        case .donate: "Donate"
        case .careers: "Apply for Jobs"
        case .leetCode: "Leet Code"
        case .mockInterviews: "Mock Interviews"
        case .discoverGames: "Discover"
        case .gameResources: "Resources"
        case .timeline: "Timeline"
        case .profile: "Profile"
        case .demographics: "Demographic Info"
        case .about: "About Tatum Games"
        case .faq: "FAQ"
        }
    }

    var systemImage: String {
        switch self {
        case .scanner: "qrcode.viewfinder"
        case .codingChallenges, .leetCode: "chevron.left.forwardslash.chevron.right"
        case .aiChallenges: "sparkles"
        case .stats: "chart.bar"
        case .resources, .gameResources: "books.vertical"
        case .community: "person.3"
        case .donate: "heart"
        case .careers: "briefcase"
        case .mockInterviews: "person.2.wave.2"
        case .discoverGames: "gamecontroller"
        case .timeline: "calendar"
        case .profile: "person.crop.circle"
        case .demographics: "list.bullet.clipboard"
        case .about: "info.circle"
        case .faq: "questionmark.circle"
        }
    }
}

/// Placeholder for a destination that is not available on iOS yet.
struct PendingFeatureView: View {
    let feature: PendingFeature

    var body: some View {
        ContentUnavailableView {
            Label(feature.title, systemImage: feature.systemImage)
        } description: {
            Text("This feature is coming soon to iPhone.")
        }
        .background(Palette.screenBackground)
        .navigationTitle(feature.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
