import SwiftUI
import TatumTechKit

/// Progress overview: activity rings, accuracy, streak, per-category completions, coding totals,
/// and every achievement with its unlock state.
struct StatsView: View {
    @Environment(AppModel.self) private var app
    @State private var summary: StatsSummary?
    @State private var achievements: [(achievement: Achievement, unlocked: Bool)] = []
    @State private var animatedEvents = 0
    @State private var animatedChallenges = 0
    @State private var animatedScans = 0
    @State private var animatedPercent = 0

    var body: some View {
        Group {
            if let summary {
                if summary.hasActivity {
                    content(summary)
                } else {
                    Text("No statistics loaded yet.")
                        .foregroundStyle(Palette.textPrimary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Palette.screenBackground.ignoresSafeArea())
        .navigationTitle("Stats")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func content(_ summary: StatsSummary) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                Text("Your Progress")
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.md)
                    .accessibilityAddTraits(.isHeader)

                HStack {
                    Spacer()
                    ProgressRing(label: "Events", value: animatedEvents, max: 20, color: Palette.brandPrimaryStrong)
                    Spacer()
                    ProgressRing(label: "Challenges", value: animatedChallenges, max: 30, color: Palette.gold)
                    Spacer()
                    ProgressRing(label: "QR Scans", value: animatedScans, max: 30, color: Palette.teal)
                    Spacer()
                }
                .padding(.bottom, Spacing.xl)

                VStack(spacing: Spacing.xs) {
                    Text("Percent Correct")
                        .font(.headline)
                    PercentRing(percent: animatedPercent)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, Spacing.xl)

                sectionTitle("Current Streak: \(summary.currentStreak) days")
                    .padding(.bottom, Spacing.xl)
                sectionTitle("Achievements Unlocked: \(summary.achievementsUnlocked)")
                    .padding(.bottom, Spacing.xl)

                sectionTitle("Category Breakdown")
                    .padding(.bottom, Spacing.xs)
                CategoryBreakdown(counts: summary.categoryCounts, total: summary.challengesCompleted)
                    .padding(.bottom, Spacing.xl)

                sectionTitle("Coding Challenge Stats")
                    .padding(.bottom, Spacing.xs)
                HStack {
                    Spacer()
                    ProgressRing(label: "Questions", value: summary.questionsAnswered, max: 100, color: Palette.brandPrimaryStrong)
                    Spacer()
                    ProgressRing(label: "Correct", value: summary.correctAnswers, max: max(summary.questionsAnswered, 1), color: Palette.gold)
                    Spacer()
                }
                .padding(.bottom, Spacing.xl)

                HStack {
                    sectionTitle("Achievements")
                    Spacer()
                    NavigationLink(value: AppRoute.achievements) {
                        Text("View All")
                            .font(.body.weight(.medium))
                            .foregroundStyle(Palette.brandPrimaryStrong)
                    }
                    .accessibilityIdentifier("stats.viewAll")
                }
                .padding(.bottom, Spacing.xs)

                ForEach(achievements, id: \.achievement.id) { item in
                    AchievementRow(achievement: item.achievement, isUnlocked: item.unlocked)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.md)
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .foregroundStyle(Palette.textPrimary)
    }

    private func load() async {
        let dependencies = app.dependencies
        let bank = await dependencies.catalog.questionBank
        _ = await ChallengeEngine(repository: dependencies.local, bank: bank).backfillCompletions()
        let definitions = (try? await dependencies.catalog.achievements()) ?? []
        let data = await dependencies.local.snapshot()
        let progress = AchievementProgress(data: data)
        let loaded = StatsSummary(data: data, achievements: definitions, calendar: .current)
        achievements = definitions.map { ($0, progress.isUnlocked($0)) }
        summary = loaded
        await countUp(to: loaded)
    }

    /// Counts each ring up one step at a time, as the numbers fill in.
    private func countUp(to summary: StatsSummary) async {
        for value in 0...summary.eventsAttended {
            animatedEvents = value
            try? await Task.sleep(for: .milliseconds(30))
        }
        for value in 0...summary.challengesCompleted {
            animatedChallenges = value
            try? await Task.sleep(for: .milliseconds(15))
        }
        for value in 0...summary.qrScans {
            animatedScans = value
            try? await Task.sleep(for: .milliseconds(15))
        }
        for value in 0...summary.percentCorrect {
            animatedPercent = value
            try? await Task.sleep(for: .milliseconds(10))
        }
    }
}

/// A 64 pt ring with its value and label underneath.
struct ProgressRing: View {
    let label: String
    let value: Int
    let max: Int
    let color: Color

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle().stroke(color.opacity(0.2), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut, value: progress)
            }
            .frame(width: 64, height: 64)
            .padding(.bottom, Spacing.xs)
            Text("\(value)")
                .font(.body.bold())
                .monospacedDigit()
            Text(label)
                .font(.footnote)
                .foregroundStyle(Palette.grey)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("\(value)")
    }

    private var progress: CGFloat {
        guard max > 0 else { return 0 }
        return CGFloat(min(Swift.max(Double(value) / Double(max), 0), 1))
    }
}

private struct PercentRing: View {
    let percent: Int

    var body: some View {
        let clamped = min(max(percent, 0), 100)
        ZStack {
            Circle().stroke(Palette.tealDeep.opacity(0.2), lineWidth: 10)
            Circle()
                .trim(from: 0, to: CGFloat(clamped) / 100)
                .stroke(Palette.tealDeep, style: StrokeStyle(lineWidth: 10))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut, value: clamped)
            Text("\(clamped)%")
                .font(.system(size: 20, weight: .bold))
                .monospacedDigit()
        }
        .frame(width: 100, height: 100)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Percent Correct")
        .accessibilityValue("\(clamped)%")
    }
}

private struct CategoryBreakdown: View {
    let counts: [(category: String, count: Int)]
    let total: Int

    var body: some View {
        if total <= 0 {
            Text("Complete a challenge to see your category breakdown")
                .font(.callout)
                .foregroundStyle(Palette.grey)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        } else {
            VStack(spacing: Spacing.xs) {
                ForEach(counts, id: \.category) { row in
                    HStack(spacing: 0) {
                        Text(row.category)
                            .font(.caption.weight(.medium))
                            .frame(width: 110, alignment: .leading)
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4).fill(Palette.grey.opacity(0.2))
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Palette.brandPrimaryStrong)
                                    .frame(width: proxy.size.width * fraction(row.count))
                            }
                        }
                        .frame(height: 10)
                        Text("\(row.count)")
                            .font(.caption)
                            .monospacedDigit()
                            .frame(width: 24, alignment: .leading)
                            .padding(.leading, Spacing.xs)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(row.category)
                    .accessibilityValue("\(row.count)")
                }
            }
            .padding(Spacing.sm)
            .background(RoundedRectangle(cornerRadius: Radius.medium).fill(.white))
        }
    }

    private func fraction(_ count: Int) -> CGFloat {
        CGFloat(min(max(Double(count) / Double(max(total, 1)), 0), 1))
    }
}

/// Compact achievement row: badge (faded when locked), title, and description.
struct AchievementRow: View {
    let achievement: Achievement
    let isUnlocked: Bool

    var body: some View {
        HStack(spacing: Spacing.sm) {
            BadgeImage(name: achievement.icon)
                .frame(width: 40, height: 40)
                .opacity(isUnlocked ? 1 : 0.3)
            VStack(alignment: .leading, spacing: 2) {
                Text(achievement.title)
                    .font(.subheadline.weight(isUnlocked ? .bold : .medium))
                    .foregroundStyle(Palette.textPrimary)
                Text(achievement.description)
                    .font(.callout)
                    .foregroundStyle(isUnlocked ? Color.black : Palette.grey)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityValue(isUnlocked ? "Unlocked" : "Locked")
    }
}

/// A bundled badge, falling back to the first-step badge when the image is missing.
struct BadgeImage: View {
    let name: String
    var renderingMode: Image.TemplateRenderingMode = .original

    var body: some View {
        let resolved = UIImage(named: name) != nil ? name : Achievement.fallbackIcon
        Image(resolved)
            .renderingMode(renderingMode)
            .resizable()
            .scaledToFit()
            .accessibilityHidden(true)
    }
}
