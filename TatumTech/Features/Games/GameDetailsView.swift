import SwiftUI
import TatumTechKit

/// One game: artwork, description, videos, screenshots, store links, socials, and tags.
struct GameDetailsView: View {
    let gameID: String

    @Environment(AppModel.self) private var app
    @State private var state: DetailState = .loading

    private enum DetailState {
        case loading
        case loaded(Game)
        case missing(String)
    }

    var body: some View {
        Group {
            switch state {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case let .missing(message):
                Text(message)
                    .multilineTextAlignment(.center)
                    .padding(Spacing.xl)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case let .loaded(game):
                ScrollView { GameDetailsBody(game: game) }
            }
        }
        .background(Palette.screenBackground.ignoresSafeArea())
        .navigationTitle("Game Details")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: gameID) { await load() }
    }

    private func load() async {
        do {
            if let game = try await app.dependencies.catalog.games().game(id: gameID) {
                state = .loaded(game)
            } else {
                state = .missing("Game not found.")
            }
        } catch {
            app.analytics.recordHandled(error)
            state = .missing(error.localizedDescription)
        }
    }
}

private struct GameDetailsBody: View {
    let game: Game
    @Environment(\.openURL) private var openURL
    @State private var viewerStart: ScreenshotSelection?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            if let logo = game.logo {
                GameMediaImage(media: logo)
                    .frame(width: 88, height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
                    .accessibilityLabel("\(game.title) logo")
            }
            Text(game.title)
                .font(.title.bold())
            Text(game.companyName)
                .font(.headline)
                .foregroundStyle(Palette.brandPrimaryStrong)
            HStack(spacing: Spacing.xs) {
                chip(game.statusLabel, highlighted: true)
                if !game.platformLabel.isEmpty {
                    chip(game.platformLabel, highlighted: false)
                }
            }

            GameMediaImage(media: game.heroImage)
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                .accessibilityLabel("\(game.title) screenshot")

            sectionTitle("About")
            Text(game.longDescription)
                .font(.callout)
            if game.isComingSoon {
                Text("This game is not available yet. Check back for release updates.")
                    .font(.callout)
                    .foregroundStyle(Palette.tealDeep)
            }

            if !game.promotionalVideos.isEmpty {
                sectionTitle("Videos")
                ForEach(game.promotionalVideos, id: \.self) { video in
                    videoCard(video)
                }
            }

            if !game.screenshots.isEmpty {
                sectionTitle("Screenshots")
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: Spacing.sm) {
                        ForEach(Array(game.screenshots.enumerated()), id: \.offset) { index, shot in
                            Button {
                                viewerStart = ScreenshotSelection(index: index)
                            } label: {
                                GameMediaImage(media: shot)
                                    .frame(width: 220, height: 124)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(game.title) screenshot \(index + 1)")
                            .accessibilityHint("Opens full screen")
                        }
                    }
                }
            }

            if !game.isComingSoon || game.hasOutboundLinks {
                sectionTitle(game.isComingSoon ? "Follow the game" : "Get the game")
                callsToAction
            }

            if !game.discoveryTags.isEmpty {
                sectionTitle("Tags")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.xs) {
                        ForEach(game.discoveryTags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(Palette.textSecondary)
                                .padding(.horizontal, Spacing.xs)
                                .padding(.vertical, 6)
                                .overlay(RoundedRectangle(cornerRadius: Radius.small).strokeBorder(Palette.divider))
                        }
                    }
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.xxl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fullScreenCover(item: $viewerStart) { selection in
            ScreenshotViewer(screenshots: game.screenshots, startIndex: selection.index, gameTitle: game.title)
        }
    }

    private var callsToAction: some View {
        VStack(spacing: 10) {
            ForEach(game.callsToAction, id: \.self) { action in
                Button(action.label) { openURL(action.url) }
                    .buttonStyle(StoreButtonStyle(fill: fill(for: action.kind), text: action.kind == .website ? .black : .white))
            }
            if let discord = game.social.discord {
                Button("Join Discord") { openURL(discord) }
                    .buttonStyle(.outlinedAction)
            }
            let socials = game.social.iconLinks
            if !socials.isEmpty || game.social.youtube != nil {
                HStack(spacing: Spacing.xxs) {
                    SocialLinksRow(links: socials) { openURL($0) }
                    if let youtube = game.social.youtube {
                        Button("YouTube") { openURL(youtube) }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Palette.brandPrimaryStrong)
                            .frame(minHeight: Metrics.minimumTapTarget)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func fill(for kind: GameCallToAction.Kind) -> Color {
        switch kind {
        case .googlePlay: Palette.brandPrimaryStrong
        case .appStore, .otherStore: Palette.tealDeep
        case .steam: Palette.steamDark
        case .website: Palette.lavender
        }
    }

    private func videoCard(_ video: GameVideo) -> some View {
        Button {
            openURL(video.url)
        } label: {
            ZStack {
                if let thumbnail = video.thumbnailURL {
                    ContentImage(source: .remote(thumbnail), placeholder: "games")
                } else {
                    Image("games").resizable().scaledToFill()
                }
                Image(systemName: "play.fill")
                    .font(.title)
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(Color.black.opacity(0.72)))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(game.title) video")
        .accessibilityHint("Plays in your browser")
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.title3.bold())
            .accessibilityAddTraits(.isHeader)
    }

    private func chip(_ text: String, highlighted: Bool) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(Palette.textPrimary)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                    .fill(highlighted ? Palette.teal.opacity(0.25) : Palette.lightGrey)
            )
            .padding(.vertical, Spacing.xxs)
    }
}

private struct ScreenshotSelection: Identifiable {
    let index: Int
    var id: Int { index }
}

/// Full-screen, swipeable screenshots on black.
private struct ScreenshotViewer: View {
    let screenshots: [GameMedia]
    let gameTitle: String
    @State private var page: Int
    @Environment(\.dismiss) private var dismiss

    init(screenshots: [GameMedia], startIndex: Int, gameTitle: String) {
        self.screenshots = screenshots
        self.gameTitle = gameTitle
        _page = State(initialValue: min(max(startIndex, 0), max(screenshots.count - 1, 0)))
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            TabView(selection: $page) {
                ForEach(Array(screenshots.enumerated()), id: \.offset) { index, shot in
                    GameMediaImage(media: shot, contentMode: .fit)
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, 48)
                        .accessibilityLabel("\(gameTitle) screenshot \(index + 1) of \(screenshots.count)")
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: screenshots.count > 1 ? .always : .never))
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(Color.black.opacity(0.55)))
            }
            .padding(Spacing.xs)
            .accessibilityLabel("Close screenshot viewer")
        }
    }
}

private struct StoreButtonStyle: ButtonStyle {
    let fill: Color
    let text: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(text)
            .frame(maxWidth: .infinity, minHeight: Metrics.minimumTapTarget)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(fill))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
