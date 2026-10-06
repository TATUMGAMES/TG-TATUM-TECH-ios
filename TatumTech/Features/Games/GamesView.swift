import SwiftUI
import TatumTechKit

/// Discover Games: a Featured showcase and a searchable Games tab with themed carousels.
struct GamesView: View {
    @Environment(AppModel.self) private var app
    @State private var state: CatalogState = .loading
    @State private var tab: Tab = .featured
    @State private var query = ""
    @State private var genre: String?
    @State private var gameplay: String?

    private enum Tab: Hashable { case featured, games }

    private enum CatalogState {
        case loading
        case loaded(GameCatalog)
        case failed(String)
    }

    var body: some View {
        Group {
            switch state {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case let .failed(message):
                Text(message)
                    .multilineTextAlignment(.center)
                    .padding(Spacing.xl)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case let .loaded(catalog):
                VStack(spacing: 0) {
                    Picker("Section", selection: $tab) {
                        Text("Featured").tag(Tab.featured)
                        Text("Games").tag(Tab.games)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.xs)
                    .accessibilityIdentifier("games.tabs")

                    switch tab {
                    case .featured: featured(catalog)
                    case .games: discover(catalog)
                    }
                }
            }
        }
        .background(Palette.screenBackground.ignoresSafeArea())
        .navigationTitle("Discover Games")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        guard case .loading = state else { return }
        do {
            state = .loaded(try await app.dependencies.catalog.games())
        } catch {
            app.analytics.recordHandled(error)
            state = .failed(error.localizedDescription.isEmpty ? "Something went wrong." : error.localizedDescription)
        }
    }

    @ViewBuilder
    private func featured(_ catalog: GameCatalog) -> some View {
        let showcase = catalog.games.enumerated()
            .sorted { lhs, rhs in
                lhs.element.featuredPriority != rhs.element.featuredPriority
                    ? lhs.element.featuredPriority > rhs.element.featuredPriority
                    : lhs.offset < rhs.offset
            }
            .map(\.element)
        if showcase.isEmpty {
            Text("No featured games right now. Check back soon.")
                .multilineTextAlignment(.center)
                .padding(Spacing.xl)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: Spacing.md) {
                    ForEach(showcase) { game in
                        ShowcaseGameCard(game: game) { openDetails(game) }
                    }
                    MikrosCallToActionCard()
                        .padding(.top, Spacing.xs)
                }
                .padding(Spacing.md)
            }
        }
    }

    private func discover(_ catalog: GameCatalog) -> some View {
        let filtered = catalog.filtered(query: query, genre: genre, gameplayType: gameplay)
        let carousels = GameCatalog.sections(for: filtered, now: Date()).carousels
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.lg) {
                filters(genres: catalog.genres)
                    .padding(.top, Spacing.xs)
                if carousels.isEmpty {
                    Text("No games match your filters.")
                        .frame(maxWidth: .infinity)
                        .padding(Spacing.xl)
                } else {
                    ForEach(carousels, id: \.title) { section in
                        GameCarousel(title: section.title, games: section.games, style: Self.style(for: section.title)) { game in
                            openDetails(game)
                        }
                    }
                }
                MikrosCallToActionCard()
                    .padding(.horizontal, Spacing.md)
            }
            .padding(.bottom, Spacing.xl)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func filters(genres: [String]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            TextField("Search games", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .formFieldChrome()
                .accessibilityIdentifier("games.search")
            Text("Genre")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Palette.brandPrimaryStrong)
            chips(genres, selection: $genre, idPrefix: "games.genre")
            Text("Gameplay")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Palette.brandPrimaryStrong)
            chips(GameCatalog.gameplayTypes, selection: $gameplay, idPrefix: "games.gameplay")
        }
        .padding(.horizontal, Spacing.md)
    }

    /// "All" maps to no filter.
    private func chips(_ options: [String], selection: Binding<String?>, idPrefix: String) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xs) {
                ForEach(options, id: \.self) { option in
                    let isAll = option == GameCatalog.all
                    SelectableChip(title: option, isSelected: isAll ? selection.wrappedValue == nil : selection.wrappedValue == option) {
                        selection.wrappedValue = isAll ? nil : option
                    }
                    .accessibilityIdentifier("\(idPrefix).\(option)")
                }
            }
        }
    }

    private func openDetails(_ game: Game) {
        let local = app.local
        Task { _ = await local.incrementCounter(CounterKey.gameDetailsViewed) }
        app.router.push(.gameDetails(gameID: game.id))
    }

    private static func style(for title: String) -> GameCarousel.Style {
        switch title {
        case "Tatum Games Favorites", "Core Gamer": .tall
        case "Apps in Development": .compact
        default: .wide
        }
    }
}

/// An image from the games catalog, falling back to the Games artwork.
struct GameMediaImage: View {
    let media: GameMedia?
    var contentMode: ContentMode = .fill

    var body: some View {
        ContentImage(source: source, contentMode: contentMode, placeholder: "games")
    }

    private var source: ImageSource {
        switch media {
        case let .asset(name)?: .bundled(name: name)
        case let .remote(url)?: .remote(url)
        case nil: .none
        }
    }
}

extension Game {
    /// "Coming Soon" or "Featured".
    var statusLabel: String { isComingSoon ? "Coming Soon" : "Featured" }
    /// The store for upcoming games, otherwise "Available".
    var platformLabel: String { isComingSoon ? appStore : "Available" }
}

private struct ShowcaseGameCard: View {
    let game: Game
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(alignment: .center, spacing: Spacing.md) {
                GameMediaImage(media: game.logo ?? game.featureGraphics.first)
                    .frame(width: 72, height: 72)
                    .clipped()
                VStack(alignment: .leading, spacing: 0) {
                    Text(game.title)
                        .font(.headline)
                        .foregroundStyle(Palette.textPrimary)
                    Text(game.companyName)
                        .font(.callout)
                        .foregroundStyle(Palette.brandPrimaryStrong)
                        .padding(.top, Spacing.xxs)
                    Text(game.statusLabel)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(game.isComingSoon ? Palette.tealDeep : Palette.brandPrimaryStrong)
                        .padding(.top, Spacing.xs)
                    Text(game.platformLabel)
                        .font(.caption)
                        .foregroundStyle(Palette.textPrimary)
                    Text(game.shortDescription)
                        .font(.caption)
                        .foregroundStyle(Palette.textPrimary.opacity(0.75))
                        .padding(.top, 6)
                }
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(Spacing.md)
            .cardSurface()
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(game.title), \(game.statusLabel), \(game.platformLabel)")
        .accessibilityAddTraits(.isButton)
    }
}

/// A titled horizontal row of games in one of three card styles.
private struct GameCarousel: View {
    enum Style { case compact, tall, wide }

    let title: String
    let games: [Game]
    let style: Style
    let open: (Game) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(title)
                .font(.title3.bold())
                .padding(.horizontal, Spacing.md)
                .accessibilityAddTraits(.isHeader)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: Spacing.sm) {
                    ForEach(games) { game in
                        Button { open(game) } label: { card(game) }
                            .buttonStyle(.plain)
                            .accessibilityLabel(game.title)
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xxs)
            }
        }
    }

    @ViewBuilder
    private func card(_ game: Game) -> some View {
        switch style {
        case .compact:
            VStack(alignment: .leading, spacing: 0) {
                GameMediaImage(media: game.featureGraphics.first)
                    .frame(width: 130, height: 110)
                    .clipped()
                Text(game.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(2)
                    .foregroundStyle(Palette.textPrimary)
                    .padding(Spacing.xs)
                Spacer(minLength: 0)
            }
            .frame(width: 130, height: 180)
            .background(Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        case .tall:
            GameMediaImage(media: game.featureGraphics.first)
                .frame(width: 120, height: 220)
                .clipped()
                .overlay(alignment: .bottom) {
                    Text(game.title)
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .padding(Spacing.xs)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.black.opacity(0.55))
                }
                .clipShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
        case .wide:
            HStack(spacing: 0) {
                GameMediaImage(media: game.featureGraphics.first)
                    .frame(width: 120, height: 140)
                    .clipped()
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(game.title)
                        .font(.subheadline.bold())
                        .lineLimit(2)
                    Text(game.shortDescription)
                        .font(.caption)
                        .lineLimit(3)
                }
                .foregroundStyle(Palette.textPrimary)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: 240, height: 140)
            .background(Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
        }
    }
}

/// Invites developers to learn how MIKROS can feature their game.
struct MikrosCallToActionCard: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Want your game featured here?")
                .font(.title3.bold())
            Text("Get your game discovered through MIKROS")
                .font(.headline)
                .foregroundStyle(Palette.brandPrimaryStrong)
            Text("MIKROS gives indie developers and small studios a pathway to marketing, community, and visibility across the Tatum Games ecosystem.")
                .font(.callout)
            Button("Learn More") { router.push(.getYourGameDiscovered) }
                .buttonStyle(.primary)
                .padding(.top, Spacing.xxs)
                .accessibilityIdentifier("games.mikrosLearnMore")
        }
        .foregroundStyle(Palette.textPrimary)
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                .fill(Palette.lavender)
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        )
    }
}
