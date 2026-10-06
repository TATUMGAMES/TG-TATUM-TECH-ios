import SwiftUI
import TatumTechKit

/// Vetted learning resources, filterable by technology.
struct ResourcesView: View {
    @Environment(AppModel.self) private var app
    @State private var resources: [LearningResource]?
    @State private var category = ResourceFilters.all

    var body: some View {
        Group {
            switch resources {
            case nil:
                Text("Loading resources…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case let resources? where resources.isEmpty:
                Text("No learning resources are available right now.")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case let resources?:
                list(ResourceFilters.filter(resources, category: category))
            }
        }
        .background(Palette.screenBackground.ignoresSafeArea())
        .navigationTitle("Resources")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard resources == nil else { return }
            resources = (try? await app.dependencies.catalog.resources()) ?? []
        }
    }

    private func list(_ filtered: [LearningResource]) -> some View {
        ScrollView {
            LazyVStack(spacing: Spacing.sm) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Technology")
                        .font(.subheadline.weight(.medium))
                        .padding(.vertical, Spacing.xs)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Spacing.xs) {
                            ForEach(ResourceFilters.categories, id: \.self) { option in
                                SelectableChip(title: option, isSelected: category == option) {
                                    category = option
                                }
                                .accessibilityIdentifier("resources.category.\(option)")
                            }
                        }
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.xs)

                if filtered.isEmpty {
                    Text("Come back later. We are currently looking for the best ways to help you learn. We will update you with more vetted resources soon.")
                        .foregroundStyle(Palette.grey)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.xl)
                        .padding(.vertical, 48)
                } else {
                    ForEach(filtered) { resource in
                        ResourceCard(resource: resource)
                            .padding(.horizontal, Spacing.md)
                    }
                }
            }
            .padding(.bottom, Spacing.xl)
        }
    }
}

private struct ResourceCard: View {
    let resource: LearningResource
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            if let url = resource.url { openURL(url) }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                Text(resource.title)
                    .font(.headline)
                    .foregroundStyle(Palette.textPrimary)
                if let description = resource.description, !description.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text(description)
                        .font(.callout)
                        .foregroundStyle(Palette.grey)
                        .padding(.top, Spacing.xxs)
                }
                if !resource.metadataLine.isEmpty {
                    Text(resource.metadataLine)
                        .font(.caption)
                        .foregroundStyle(Palette.brandPrimaryStrong)
                        .padding(.top, Spacing.xs)
                }
                Text("Visit →")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(Palette.brandPrimaryStrong)
                    .padding(.top, Spacing.xs)
            }
            .multilineTextAlignment(.leading)
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardSurface(cornerRadius: Radius.medium)
        }
        .buttonStyle(.plain)
        .disabled(resource.url == nil)
        .padding(.vertical, Spacing.xxs)
        .accessibilityHint("Opens in your browser")
    }
}
