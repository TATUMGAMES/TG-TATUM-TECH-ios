import SwiftUI
import TatumTechKit

struct PartnersView: View {
    @State private var model: PartnersModel
    @State private var detailPartner: Partner?
    @State private var contactPickerPartner: Partner?
    @State private var alert: AlertMessage?
    @Environment(\.openURL) private var openURL

    init(repository: any ContentRepository) {
        _model = State(initialValue: PartnersModel(repository: repository))
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.screenBackground.ignoresSafeArea())
            .navigationTitle("Partners")
            .navigationBarTitleDisplayMode(.inline)
            .task { await model.load() }
            .sheet(item: $detailPartner) { partner in
                PartnerDetailView(partner: partner, actions: actions)
            }
            .confirmationDialog(
                contactPickerTitle,
                isPresented: Binding(
                    get: { contactPickerPartner != nil },
                    set: { if !$0 { contactPickerPartner = nil } }
                ),
                titleVisibility: .visible,
                presenting: contactPickerPartner
            ) { partner in
                ForEach(partner.emailContacts, id: \.self) { contact in
                    Button("\(contact.name) · \(contact.email ?? "")") {
                        sendEmail(to: contact.email)
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .alert($alert)
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .loading:
            LoadingView(caption: "Loading partners.")
        case .failed:
            LoadFailedView { Task { await model.reload() } }
        case let .loaded(partners) where partners.isEmpty:
            EmptyStateView(message: "No partners available yet.", systemImage: "person.3")
        case .loaded:
            ScrollView {
                LazyVStack(spacing: Spacing.sm, pinnedViews: []) {
                    PartnerCategoryChips(selection: $model.selectedCategory)
                        .padding(.top, Spacing.xs)

                    let partners = model.visiblePartners
                    if partners.isEmpty {
                        Text("No partners in this category.")
                            .font(.subheadline)
                            .foregroundStyle(Palette.textSecondary)
                            .padding(Spacing.xxl)
                    } else {
                        ForEach(partners) { partner in
                            PartnerCardView(partner: partner, actions: actions) {
                                detailPartner = partner
                            }
                            .padding(.horizontal, Spacing.md)
                        }
                    }
                }
                .padding(.bottom, Spacing.xl)
            }
            .refreshable { await model.reload() }
        }
    }

    private var contactPickerTitle: String {
        guard let partner = contactPickerPartner else { return "" }
        return String(localized: "Contact \(partner.name)")
    }

    private var actions: PartnerActions {
        PartnerActions(
            open: { url in open(url, failure: String(localized: "Unable to open link")) },
            contact: contact,
            call: { number in
                guard let url = PartnerContactLinks.phoneURL(for: number) else { return }
                open(url, failure: String(localized: "Unable to start phone dialer"))
            }
        )
    }

    /// One email contact opens Mail directly; several show a picker first.
    private func contact(_ partner: Partner) {
        let contacts = partner.emailContacts
        if contacts.count > 1 {
            detailPartner = nil
            contactPickerPartner = partner
        } else {
            sendEmail(to: contacts.first?.email)
        }
    }

    private func sendEmail(to address: String?) {
        guard let address, let url = PartnerContactLinks.emailURL(to: address) else { return }
        open(url, failure: String(localized: "No email app available"))
    }

    private func open(_ url: URL, failure: String) {
        openURL(url) { accepted in
            if !accepted { alert = .simple(failure) }
        }
    }
}

/// What partner cards can ask the screen to do.
struct PartnerActions {
    let open: (URL) -> Void
    let contact: (Partner) -> Void
    let call: (String) -> Void
}

private struct PartnerCategoryChips: View {
    @Binding var selection: PartnerCategory?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xs) {
                chip(title: "All", category: nil)
                ForEach(PartnerCategory.filterable, id: \.self) { category in
                    chip(title: LocalizedStringKey(category.shortName), category: category)
                }
            }
            .padding(.horizontal, Spacing.md)
        }
    }

    private func chip(title: LocalizedStringKey, category: PartnerCategory?) -> some View {
        let isSelected = selection == category
        return Button {
            selection = category
        } label: {
            HStack(spacing: Spacing.xxs) {
                if isSelected {
                    Image(systemName: "checkmark").font(.caption.weight(.bold))
                }
                Text(title)
            }
            .font(.subheadline)
            .padding(.horizontal, Spacing.sm)
            .frame(minHeight: 36)
            .foregroundStyle(Palette.textPrimary)
            .background(
                RoundedRectangle(cornerRadius: Radius.small)
                    .fill(isSelected ? Palette.iconBackground : Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.small)
                    .strokeBorder(isSelected ? Color.clear : Palette.divider, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
