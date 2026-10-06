import SwiftUI

/// Home: greeting, category chips, and a swipeable grid of feature cards per category.
struct HomeView: View {
    @Environment(AppModel.self) private var app
    @State private var category: HomeCategory = .events
    @State private var isAccountPresented = false

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
        }
        .background(Palette.surface.ignoresSafeArea())
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
            if let name = app.displayName {
                Text("Hello, \(name)!")
            } else {
                Text("Hello!")
            }
        }
        .font(.largeTitle.bold())
        .foregroundStyle(Palette.textPrimary)
        .accessibilityAddTraits(.isHeader)
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

/// Two cards per row; an odd last card spans the full width, as on Android.
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
