import SwiftUI
import TatumTechKit

/// Partners that help with game development, grouped by what they offer.
struct GamesResourcesView: View {
    @Environment(AppModel.self) private var app
    @State private var sections: [GamesResourceSection]?

    var body: some View {
        Group {
            switch sections {
            case nil:
                Text("Loading resources…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case let sections? where sections.isEmpty:
                Text("No game development resources are available right now.")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case let sections?:
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Spacing.sm) {
                        ForEach(sections, id: \.category) { section in
                            Text(section.category)
                                .font(.headline)
                                .padding(.top, Spacing.xs)
                                .padding(.bottom, Spacing.xxs)
                                .accessibilityAddTraits(.isHeader)
                            ForEach(section.partners) { partner in
                                ResourcePartnerCard(partner: partner)
                            }
                        }
                    }
                    .padding(Spacing.md)
                }
            }
        }
        .background(Palette.screenBackground.ignoresSafeArea())
        .navigationTitle("Games Resources")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        guard sections == nil else { return }
        let categories = (try? await app.dependencies.catalog.gamesResources()) ?? []
        let partners = (try? await app.content.partners()) ?? []
        sections = GamesResourcesResolver.resolve(categories, partners: partners)
    }
}

private struct ResourcePartnerCard: View {
    let partner: Partner
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Spacing.sm) {
                PartnerLogo(partner: partner, size: 56)
                Text(partner.name)
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let summary = partner.summary, !summary.isEmpty {
                Text(summary)
                    .font(.callout)
                    .foregroundStyle(Palette.grey)
                    .padding(.top, Spacing.xs)
            }
            if let website = partner.websiteURL {
                Button("Visit Website →") { openURL(website) }
                    .font(.callout.weight(.medium))
                    .foregroundStyle(Palette.brandPrimaryStrong)
                    .frame(maxWidth: .infinity, minHeight: Metrics.minimumTapTarget, alignment: .trailing)
                    .padding(.top, Spacing.xxs)
            }
        }
        .padding(Spacing.md)
        .cardSurface(cornerRadius: Radius.medium)
    }
}
