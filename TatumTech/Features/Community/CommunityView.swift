import SwiftUI
import TatumTechKit

/// Live details of the Tatum Tech Discord server with join and sponsorship links.
struct CommunityView: View {
    @Environment(AppModel.self) private var app
    @State private var state: ServerState = .loading

    private enum ServerState {
        case loading
        case loaded(DiscordServerInfo)
        case failed(String)
    }

    var body: some View {
        Group {
            switch state {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case let .failed(message):
                Text("Error: \(message)")
                    .multilineTextAlignment(.center)
                    .padding(Spacing.md)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case let .loaded(info):
                ServerDetails(info: info)
            }
        }
        .background(Palette.screenBackground.ignoresSafeArea())
        .navigationTitle("Join Our Community")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        guard case .loading = state else { return }
        do throws(DiscordError) {
            state = .loaded(try await app.dependencies.discord.serverInfo())
        } catch {
            state = .failed(error.message)
        }
    }
}

private struct ServerDetails: View {
    let info: DiscordServerInfo
    @Environment(\.openURL) private var openURL
    @State private var copiedInvite = false

    private static let discordPink = Color(hex: 0xEB459E)
    private static let discordGold = Color(hex: 0xFAA61A)

    var body: some View {
        let inviteCode = info.inviteCode()
        let inviteURL = DiscordServerInfo.inviteURL(code: inviteCode)
        ScrollView {
            VStack(spacing: Spacing.md) {
                banner

                HStack(spacing: Spacing.md) {
                    icon
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(info.serverName ?? "MIKROS Mafia")
                            .font(.title2)
                        HStack(spacing: Spacing.xs) {
                            Button(copiedInvite ? "Copied" : "discord.gg/\(inviteCode)") {
                                UIPasteboard.general.url = inviteURL
                                copiedInvite = true
                            }
                            .font(.callout)
                            .foregroundStyle(Palette.discordBlurple)
                            .accessibilityHint("Copies the invite link")
                            .task(id: copiedInvite) {
                                guard copiedInvite else { return }
                                try? await Task.sleep(for: .seconds(1.5))
                                copiedInvite = false
                            }
                            if let inviteURL {
                                ShareLink(item: inviteURL, subject: Text("Share Discord Invite")) {
                                    Image(systemName: "square.and.arrow.up")
                                        .foregroundStyle(Palette.discordBlurple)
                                        .frame(width: Metrics.minimumTapTarget, height: Metrics.minimumTapTarget)
                                }
                                .accessibilityLabel("Share Invite")
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }

                HStack {
                    stat(systemImage: "face.smiling", tint: Palette.discordBlurple, label: "Members",
                         text: "\(info.memberCount.map(String.init) ?? "-") Members")
                    stat(systemImage: "hand.thumbsup.fill", tint: Palette.discordGreen, label: "Online",
                         text: "\(info.onlineCount.map(String.init) ?? "-") Online")
                    VStack(spacing: Spacing.xxs) {
                        Image(systemName: "star.fill").foregroundStyle(Self.discordPink)
                            .accessibilityLabel("Boost Level")
                        Text("Boost Lv. \(info.boostLevel.map(String.init) ?? "-")")
                        if let boosts = info.boostCount {
                            Text("\(boosts) boosts").font(.caption)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .multilineTextAlignment(.center)

                if let description = info.serverDescription, !description.isEmpty {
                    Text(description)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }

                if let online = info.onlineCount, online > 0 {
                    onlineAvatars(online)
                }

                Button("Join MIKROS Mafia") { openURL(AppLinks.discordInvite) }
                    .buttonStyle(.primary)
                    .accessibilityIdentifier("community.join")
                Button("Support Us") { openURL(AppLinks.supportUs) }
                    .buttonStyle(.primary)
                    .accessibilityIdentifier("community.support")
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.md)
        }
    }

    private var banner: some View {
        let shape = RoundedRectangle(cornerRadius: 4)
        return Group {
            if let url = info.bannerURL {
                ContentImage(source: .remote(url), placeholder: "discord_banner")
            } else {
                Image("discord_banner").resizable().scaledToFill()
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .clipShape(shape)
        .overlay(shape.strokeBorder(Palette.brandPrimary, lineWidth: 2))
        .accessibilityLabel("Server Banner")
    }

    @ViewBuilder
    private var icon: some View {
        if let url = info.iconURL {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.white
            }
            .frame(width: 64, height: 64)
            .background(Color.white)
            .clipShape(Circle())
            .accessibilityLabel("Server Icon")
        } else {
            Text(info.initial)
                .frame(width: 64, height: 64)
                .background(Circle().fill(Palette.lightGrey))
                .accessibilityLabel("Server Icon")
        }
    }

    private func stat(systemImage: String, tint: Color, label: String, text: String) -> some View {
        VStack(spacing: Spacing.xxs) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .accessibilityLabel(label)
            Text(text)
        }
        .frame(maxWidth: .infinity)
    }

    private func onlineAvatars(_ online: Int) -> some View {
        let colors = [Palette.discordBlurple, Palette.discordGreen, Self.discordPink, Self.discordGold]
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xs) {
                ForEach(0..<min(online, 8), id: \.self) { index in
                    Image(systemName: "person.fill")
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(colors[index % colors.count]))
                }
                if online > 8 {
                    Text("+\(online - 8) more")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(online) online")
    }
}
