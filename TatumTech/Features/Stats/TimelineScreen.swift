import SwiftUI
import TatumTechKit

/// Recent activity for the last day, week, or month, newest first.
struct TimelineScreen: View {
    @Environment(AppModel.self) private var app
    @State private var filter: TimelineFilter = .today
    @State private var entries: [TimelineEntry] = []

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Spacing.sm) {
                ForEach(TimelineFilter.allCases, id: \.self) { option in
                    SelectableChip(title: option.title, isSelected: filter == option) {
                        filter = option
                    }
                    .accessibilityIdentifier("timeline.filter.\(option.rawValue)")
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)

            if entries.isEmpty {
                Text("No activity during this period")
                    .foregroundStyle(Palette.grey)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Spacing.xl) {
                        ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                            TimelineRow(entry: entry, isLast: index == entries.count - 1)
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.md)
                }
            }
        }
        .padding(.top, Spacing.xs)
        .background(Palette.screenBackground.ignoresSafeArea())
        .navigationTitle("My Timeline")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: filter) {
            entries = await app.local.timeline(since: filter.start(from: Date()))
        }
    }
}

private extension TimelineFilter {
    var title: String {
        switch self {
        case .today: "Today"
        case .week: "Last Week"
        case .month: "Last Month"
        }
    }
}

private struct TimelineRow: View {
    let entry: TimelineEntry
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Palette.brandPrimaryStrong)
                    .frame(width: 16, height: 16)
                if !isLast {
                    Rectangle()
                        .fill(Palette.lightGrey)
                        .frame(width: 4, height: 48)
                }
            }
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text(entry.description)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Palette.textPrimary)
                Text(entry.timestamp, format: Self.timestampFormat)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.brandPrimaryStrong)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// "Mar 4, 2026 3:05 PM" in the user's locale.
    private static let timestampFormat = Date.FormatStyle()
        .month(.abbreviated).day().year()
        .hour().minute()
}
