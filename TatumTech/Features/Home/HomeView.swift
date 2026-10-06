import SwiftUI
import TatumTechKit

/// Home: greeting, category chips, a swipeable grid of feature cards per category, and recent
/// notifications.
struct HomeView: View {
    @Environment(AppModel.self) private var app
    @Environment(AppRouter.self) private var router
    @State private var category: HomeCategory = .events
    @State private var isAccountPresented = false
    @State private var notifications: [RecentNotification] = []
    @State private var notificationsExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            greeting
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.xs)

            CategoryChipBar(selection: $category)
                .padding(.top, Spacing.xl)
                .padding(.bottom, Spacing.xs)

            TabView(selection: $category) {
                ForEach(HomeCategory.allCases) { category in
                    FeatureGrid(items: HomeCatalog.items(for: category))
                        .tag(category)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: category)

            RecentNotificationsSection(
                notifications: notifications,
                isExpanded: $notificationsExpanded,
                open: open
            )
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.md)
        }
        .background(Palette.surface.ignoresSafeArea())
        .task { await refresh() }
        .navigationTitle("Tatum Tech")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isAccountPresented = true
                } label: {
                    Image(systemName: "line.3.horizontal")
                }
                .accessibilityLabel("Menu")
                .accessibilityIdentifier("home.menu")
            }
        }
        .sheet(isPresented: $isAccountPresented) {
            AccountSheet()
        }
    }

    private var greeting: some View {
        Group {
            if app.greetingName.isEmpty {
                Text("Hello!")
            } else {
                Text("Hello, \(app.greetingName)!")
            }
        }
        .font(.largeTitle.bold())
        .foregroundStyle(Palette.textPrimary)
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("home.greeting")
    }

    /// Reloads the profile name and today's notifications each time Home appears.
    private func refresh() async {
        await app.refreshLocalUser()
        let events = (try? await app.content.upcomingEvents()) ?? []
        let hasQuestions = await !app.dependencies.catalog.questionBank.isEmpty
        notifications = await app.local.refreshNotifications(events: events, hasChallengeQuestions: hasQuestions)
    }

    private func open(_ notification: RecentNotification) {
        let local = app.local
        Task {
            await local.markNotificationRead(id: notification.id)
            await refresh()
        }
        router.open(notification.destination)
    }
}

/// Collapsible list of recent notifications; unread ones are tinted and dotted.
private struct RecentNotificationsSection: View {
    let notifications: [RecentNotification]
    @Binding var isExpanded: Bool
    let open: (RecentNotification) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var contentHeight: CGFloat = 0

    private static let maxListHeight: CGFloat = 200

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) { isExpanded.toggle() }
            } label: {
                HStack {
                    Text("Recent Notifications")
                        .font(.subheadline.bold())
                        .foregroundStyle(Palette.textPrimary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(Palette.textPrimary)
                }
                .padding(.vertical, Spacing.xxs)
                .frame(minHeight: Metrics.minimumTapTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isExpanded ? "Collapse recent notifications" : "Expand recent notifications")
            .accessibilityIdentifier("home.notifications.toggle")

            if isExpanded {
                ScrollView {
                    VStack(spacing: Spacing.xs) {
                        if notifications.isEmpty {
                            Text("No recent notifications")
                                .font(.callout)
                                .foregroundStyle(Palette.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, Spacing.xs)
                        } else {
                            ForEach(notifications) { notification in
                                NotificationRow(notification: notification) { open(notification) }
                            }
                        }
                    }
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
                }
                .scrollBounceBehavior(.basedOnSize)
                .frame(height: min(contentHeight, Self.maxListHeight))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

private struct NotificationRow: View {
    let notification: RecentNotification
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.md) {
                Image(notification.iconName)
                    .resizable()
                    .scaledToFit()
                    .padding(Spacing.xs)
                    .frame(width: 40, height: 40)
                    .background(RoundedRectangle(cornerRadius: Radius.small).fill(Palette.lavender))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 0) {
                    Text(notification.title)
                        .font(.system(size: 16, weight: notification.isUnread ? .semibold : .medium))
                        .foregroundStyle(.black)
                    Text(notification.description)
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.grey)
                }
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                if notification.isUnread {
                    Circle()
                        .fill(Palette.brandPrimaryStrong)
                        .frame(width: 8, height: 8)
                        .accessibilityHidden(true)
                }
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                    .fill(notification.isUnread ? Palette.lavender.opacity(0.55) : Palette.lightGrey)
            )
            .contentShape(RoundedRectangle(cornerRadius: Radius.medium))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityValue(notification.isUnread ? "Unread" : "")
    }
}

/// Horizontally scrolling category selector above the feature pager.
private struct CategoryChipBar: View {
    @Binding var selection: HomeCategory

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.xs) {
                    ForEach(HomeCategory.allCases) { category in
                        let isSelected = category == selection
                        Button {
                            selection = category
                        } label: {
                            Text(category.title)
                                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                                .padding(.horizontal, Spacing.md)
                                .frame(minHeight: 36)
                                .foregroundStyle(isSelected ? Palette.textPrimary : Palette.textSecondary)
                                .background(Capsule().fill(isSelected ? Palette.brandPrimary : Palette.featureCardBackground))
                        }
                        .buttonStyle(.plain)
                        .id(category)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                        .accessibilityIdentifier("home.category.\(category.rawValue)")
                    }
                }
                .padding(.horizontal, Spacing.md)
            }
            .onChange(of: selection) { _, newValue in
                withAnimation { proxy.scrollTo(newValue, anchor: .center) }
            }
        }
    }
}

/// Two cards per row; an odd last card spans the full width.
private struct FeatureGrid: View {
    let items: [FeatureItem]

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                ForEach(rows, id: \.first?.id) { row in
                    HStack(spacing: Spacing.md) {
                        ForEach(row) { item in
                            NavigationLink(value: item.route) {
                                FeatureCardView(item: item)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("feature.\(item.id)")
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
        }
    }

    private var rows: [[FeatureItem]] {
        stride(from: 0, to: items.count, by: 2).map { Array(items[$0..<min($0 + 2, items.count)]) }
    }
}

private struct FeatureCardView: View {
    let item: FeatureItem

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Image(item.imageName)
                .resizable()
                .scaledToFit()
                .padding(6)
                .frame(width: 36, height: 36)
                .background(RoundedRectangle(cornerRadius: Radius.small).fill(Palette.iconBackground))
                .accessibilityHidden(true)
            Text(item.title)
                .font(.body.weight(.medium))
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                .fill(Palette.featureCardBackground)
                .shadow(color: .black.opacity(0.12), radius: 3, x: 0, y: 2)
        )
        .contentShape(RoundedRectangle(cornerRadius: Radius.medium))
    }
}
