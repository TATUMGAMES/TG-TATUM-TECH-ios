import SwiftUI
import TatumTechKit

/// Which page the About screen shows.
enum AboutContent: String, Hashable {
    case about, faq

    var title: String {
        switch self {
        case .about: "About Tatum Games"
        case .faq: "FAQ"
        }
    }
}

/// About Tatum Games (mission, impact, products, MIKROS resources) or the FAQ.
struct AboutView: View {
    let content: AboutContent

    var body: some View {
        ScrollView {
            switch content {
            case .about: AboutPage()
            case .faq: FAQPage()
            }
        }
        .background(Palette.screenBackground.ignoresSafeArea())
        .navigationTitle(content.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AboutPage: View {
    @Environment(\.openURL) private var openURL

    private static let mikrosResources: [(title: String, description: String, url: URL)] = [
        ("MIKROS Explainer", "Powerful infrastructure and technologies built by developers for developers.", AppLinks.mikrosExplainerVideo),
        ("MIKROS Marketing Tutorial", "Launch game marketing campaigns in minutes.", AppLinks.mikrosMarketingTutorial),
        ("MIKROS Analytics — Integration Tutorial", "World's leading in-app data analytics and insights.", AppLinks.mikrosAnalyticsIntegration),
        ("MIKROS Analytics — Logging Events", "Log custom events tutorial.", AppLinks.mikrosAnalyticsLogging),
        ("MIKROS Technical Documentation", "SDK integration, analytics, APIs, and developer documentation.", AppLinks.mikrosDocumentation)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            Text(linkified: "Tatum Games is a Google-backed startup on a mission to innovate the mobile gaming industry while creating pathways for underrepresented communities in tech. Learn more at https://www.tatumgames.com")
                .font(.callout)

            section("Our Mission", "We create opportunities for underrepresented communities in tech and gaming by providing free computers, training, and mentorship to build the next generation of game developers.")
            section("Our Impact", "With only 2% of game developers being Black and 3% Latinx, we're working to change the future by empowering diverse voices to create, lead, and innovate in gaming.")

            VStack(alignment: .leading, spacing: 0) {
                section("What is Tatum Tech?", "Tatum Tech is a workforce-development and game-production program operated by Tatum Games that helps aspiring developers, artists, designers, programmers, and creators build practical AI and game-development skills through hands-on production. Participants work in multidisciplinary teams to create original games and intellectual property, learn from industry professionals, and develop portfolio-quality projects using the broader Tatum Games technology ecosystem.")
                resourceRow(title: "Visit Tatum Tech", description: nil, url: AppLinks.tatumTech)
                    .padding(.top, Spacing.sm)
            }

            section("Orchestra AI", "Orchestra is Tatum Games' AI orchestration and production platform for accelerating game development from idea to production-ready output. It coordinates AI models, agents, tools, and development workflows to help creators build and iterate on games more efficiently.")
            section("MIKROS Analytics", "Understand your players with game analytics, benchmarking, player intelligence, and data-driven insights designed to help developers make better decisions.")
            section("MIKROS Marketing", "Launch and manage game marketing campaigns designed specifically for developers and studios, helping games reach players across the broader Tatum Games ecosystem.")

            VStack(alignment: .leading, spacing: Spacing.xs) {
                sectionTitle("MIKROS Resources")
                ForEach(Self.mikrosResources, id: \.title) { resource in
                    resourceRow(title: resource.title, description: resource.description, url: resource.url)
                }
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                sectionTitle("Join the MIKROS Mafia")
                Text(linkified: "Connect with game developers, influencers, and industry insiders. Get support, exclusive perks, and early access to opportunities. Join us on Discord: https://discord.com/invite/6FzqSUDRXQ")
                    .font(.callout)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func section(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            sectionTitle(title)
            Text(body).font(.callout)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.title3.bold())
            .foregroundStyle(Palette.textPrimary)
            .background(Color(hex: 0xD1C4E9))
            .accessibilityAddTraits(.isHeader)
    }

    private func resourceRow(title: String, description: String?, url: URL) -> some View {
        Button {
            openURL(url)
        } label: {
            HStack(spacing: Spacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.medium))
                    if let description {
                        Text(description).font(.caption)
                    }
                }
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Image(systemName: "arrow.forward")
                    .foregroundStyle(Palette.brandPrimaryStrong)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, Spacing.sm)
            .background(RoundedRectangle(cornerRadius: Radius.medium).fill(Palette.lightGrey))
            .contentShape(RoundedRectangle(cornerRadius: Radius.medium))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isLink)
    }
}

private struct FAQPage: View {
    private static let entries: [(question: String, answer: String)] = [
        ("What is Tatum Tech?", "Tatum Tech is a workforce-development and game-production program that helps aspiring creators build AI and game-development skills through hands-on production, mentorship, and portfolio-quality projects."),
        ("Who can attend Tatum Tech events?", "Anyone can attend! We especially welcome participants from underrepresented communities, including women, people of color, and individuals from low-income backgrounds."),
        ("How do I register for events?", "You can register through this app by visiting the Upcoming Events section. Just tap \"Register\" on any available event. Registration is completely free.")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("General Questions")
                .font(.title3.bold())
                .accessibilityAddTraits(.isHeader)
            ForEach(Self.entries, id: \.question) { entry in
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(entry.question).font(.headline)
                    Text(entry.answer).font(.callout)
                }
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension Text {
    /// Text whose web addresses are tappable links.
    init(linkified string: String) {
        var attributed = AttributedString(string)
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            let range = NSRange(string.startIndex..., in: string)
            for match in detector.matches(in: string, range: range) {
                guard let url = match.url,
                      let stringRange = Range(match.range, in: string),
                      let lower = AttributedString.Index(stringRange.lowerBound, within: attributed),
                      let upper = AttributedString.Index(stringRange.upperBound, within: attributed)
                else { continue }
                attributed[lower..<upper].link = url
                attributed[lower..<upper].foregroundColor = Palette.brandPrimaryStrong
            }
        }
        self.init(attributed)
    }
}
