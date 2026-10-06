import SwiftUI
import TatumTechKit

/// Every achievement as a card with its requirements and point value.
struct AchievementsView: View {
    @Environment(AppModel.self) private var app
    @State private var items: [(achievement: Achievement, unlocked: Bool)]?

    var body: some View {
        Group {
            if let items {
                ScrollView {
                    LazyVStack(spacing: Spacing.sm) {
                        ForEach(items, id: \.achievement.id) { item in
                            AchievementCard(achievement: item.achievement, isUnlocked: item.unlocked)
                        }
                    }
                    .padding(Spacing.md)
                }
            } else {
                Text("Loading achievements…")
                    .font(.body)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Palette.screenBackground.ignoresSafeArea())
        .navigationTitle("Achievements")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let definitions = (try? await app.dependencies.catalog.achievements()) ?? []
            let progress = AchievementProgress(data: await app.local.snapshot())
            items = definitions.map { ($0, progress.isUnlocked($0)) }
        }
    }
}

private struct AchievementCard: View {
    let achievement: Achievement
    let isUnlocked: Bool

    var body: some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                Circle().fill(isUnlocked ? Palette.brandPrimaryStrong : Palette.grey)
                BadgeImage(name: achievement.icon, renderingMode: .template)
                    .foregroundStyle(isUnlocked ? Color.white : Palette.textPrimary.opacity(0.6))
                    .frame(width: 24, height: 24)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(achievement.title)
                    .font(.headline)
                    .foregroundStyle(Palette.textPrimary.opacity(isUnlocked ? 1 : 0.6))
                Text(achievement.description)
                    .font(.callout)
                    .foregroundStyle(Palette.textPrimary.opacity(isUnlocked ? 1 : 0.6))
                Text(achievement.requirements)
                    .font(.caption)
                    .foregroundStyle(isUnlocked ? Palette.brandPrimaryStrong : Palette.textPrimary.opacity(0.5))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("+\(achievement.points)")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, Spacing.xs)
                .padding(.vertical, Spacing.xxs)
                .background(RoundedRectangle(cornerRadius: Radius.medium).fill(badgeColor))
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                .fill(.white)
                .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
        )
        .padding(.vertical, Spacing.xxs)
        .accessibilityElement(children: .combine)
        .accessibilityValue(isUnlocked ? "Unlocked" : "Locked")
    }

    /// Point badge color by value; grey while locked.
    private var badgeColor: Color {
        guard isUnlocked else { return Palette.mediumGrey.opacity(0.45) }
        switch achievement.points {
        case 100...: return Palette.purpleDeep
        case 25...: return Palette.deepOrange
        case 15...: return Palette.brandPrimaryStrong
        default: return Palette.successGreen
        }
    }
}
