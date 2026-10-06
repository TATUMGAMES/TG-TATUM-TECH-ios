import SwiftUI
import TatumTechKit

/// Open job listings with search and category / employment-type filters.
struct CareerView: View {
    @Environment(AppModel.self) private var app
    @State private var listings: [CareerListing]?
    @State private var query = ""
    @State private var category = CareerFilters.all
    @State private var employmentType = CareerFilters.all

    var body: some View {
        Group {
            switch listings {
            case nil:
                Text("Loading career opportunities…")
                    .font(.callout)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case let listings? where listings.isEmpty:
                Text("No open listings right now. Check back soon.")
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .padding(Spacing.xl)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case let listings?:
                list(listings)
            }
        }
        .background(Palette.screenBackground.ignoresSafeArea())
        .navigationTitle("Career")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard listings == nil else { return }
            listings = (try? await app.dependencies.catalog.careers()) ?? []
        }
    }

    private func list(_ listings: [CareerListing]) -> some View {
        let filtered = CareerFilters.filter(listings, query: query, category: category, employmentType: employmentType)
        return ScrollView {
            LazyVStack(spacing: Spacing.sm) {
                filters
                if filtered.isEmpty {
                    VStack(spacing: Spacing.xs) {
                        Text("No jobs found")
                            .font(.headline)
                        Text("Try changing your search or filters.")
                            .font(.callout)
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)
                    .padding(.vertical, 48)
                } else {
                    ForEach(filtered) { listing in
                        CareerCard(listing: listing)
                            .padding(.horizontal, Spacing.md)
                    }
                }
            }
            .padding(.bottom, Spacing.xl)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var filters: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            TextField("Search jobs, companies, or technologies", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .formFieldChrome()
                .accessibilityIdentifier("career.search")

            Text("Job Category")
                .font(.subheadline.weight(.medium))
            chipRow(CareerFilters.categories, selection: $category, idPrefix: "career.category")

            Text("Employment Type")
                .font(.subheadline.weight(.medium))
            chipRow(CareerFilters.employmentTypes, selection: $employmentType, idPrefix: "career.type")

            if CareerFilters.isFiltering(query: query, category: category, employmentType: employmentType) {
                Button("Clear filters") {
                    query = ""
                    category = CareerFilters.all
                    employmentType = CareerFilters.all
                }
                .font(.callout)
                .foregroundStyle(Palette.brandPrimaryStrong)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .accessibilityIdentifier("career.clearFilters")
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.xs)
    }

    private func chipRow(_ options: [String], selection: Binding<String>, idPrefix: String) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xs) {
                ForEach(options, id: \.self) { option in
                    SelectableChip(title: option, isSelected: selection.wrappedValue == option) {
                        selection.wrappedValue = option
                    }
                    .accessibilityIdentifier("\(idPrefix).\(option)")
                }
            }
        }
    }
}

private struct CareerCard: View {
    let listing: CareerListing
    @Environment(AppModel.self) private var app
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(listing.title)
                .font(.headline)
                .foregroundStyle(Palette.textPrimary)
            Text(listing.company)
                .font(.callout)
                .foregroundStyle(Palette.brandPrimaryStrong)
                .padding(.top, Spacing.xxs)
            HStack(spacing: Spacing.xs) {
                tag(listing.category)
                tag(listing.employmentType)
            }
            .padding(.top, Spacing.xs)
            Text(listing.description)
                .font(.callout)
                .foregroundStyle(Palette.textPrimary)
                .padding(.top, Spacing.xs)
            if !listing.technologies.isEmpty {
                Text(listing.technologies.joined(separator: " • "))
                    .font(.caption)
                    .foregroundStyle(Palette.textPrimary.opacity(0.7))
                    .padding(.top, Spacing.xs)
            }
            if let url = listing.applyURL {
                Button("Apply →") {
                    let local = app.local
                    Task { _ = await local.incrementCounter(CounterKey.jobApplyClicked) }
                    openURL(url)
                }
                .font(.callout)
                .foregroundStyle(Palette.brandPrimaryStrong)
                .frame(maxWidth: .infinity, minHeight: Metrics.minimumTapTarget, alignment: .trailing)
                .padding(.top, Spacing.xxs)
                .accessibilityHint("Opens the job posting")
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(cornerRadius: Radius.medium)
        .padding(.vertical, Spacing.xxs)
    }

    private func tag(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .foregroundStyle(Palette.textSecondary)
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, 6)
            .overlay(RoundedRectangle(cornerRadius: Radius.small).strokeBorder(Palette.divider))
    }
}
