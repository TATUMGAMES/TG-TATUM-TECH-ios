import SwiftUI
import TatumTechKit

/// Directory card: logo, name, category, summary, primary actions, and social links.
struct PartnerCardView: View {
    let partner: Partner
    let actions: PartnerActions
    let openDetails: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Button(action: openDetails) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack(spacing: Spacing.sm) {
                        PartnerLogo(partner: partner, size: 56)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(partner.name)
                                .font(.headline)
                                .foregroundStyle(Palette.textPrimary)
                            Text(partner.category.shortName)
                                .font(.caption)
                                .foregroundStyle(Palette.brandPrimaryStrong)
                            if partner.isFeatured {
                                FeaturedBadge()
                            }
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Palette.textSecondary)
                            .accessibilityHidden(true)
                    }
                    if let summary = partner.summary {
                        Text(summary)
                            .font(.subheadline)
                            .foregroundStyle(Palette.textPrimary)
                            .multilineTextAlignment(.leading)
                    }
                    if let product = partner.productName {
                        Text("Product: \(product)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Palette.textPrimary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Shows partner details")

            PartnerActionButtons(partner: partner, actions: actions, isCompact: true)
            SocialLinksRow(links: partner.socialLinks, open: actions.open)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(cornerRadius: Radius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                .strokeBorder(partner.isFeatured ? Palette.featuredAccent : Color.clear, lineWidth: 2)
        )
    }
}

/// Everything known about a partner, shown as a sheet.
struct PartnerDetailView: View {
    let partner: Partner
    let actions: PartnerActions
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    PartnerLogo(partner: partner, size: 72)
                    if partner.isFeatured {
                        FeaturedBadge()
                    }
                    Text(partner.category.fullName)
                        .font(.subheadline)
                        .foregroundStyle(Palette.brandPrimaryStrong)
                    if let summary = partner.summary {
                        Text(summary)
                            .font(.body)
                            .foregroundStyle(Palette.textPrimary)
                    }
                    ForEach(partner.contacts, id: \.self) { contact in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(contact.name).font(.subheadline.weight(.semibold))
                            if let title = contact.title { Text(title).font(.caption) }
                            if let email = contact.email { Text(email).font(.caption).textSelection(.enabled) }
                            if let phone = contact.phone { Text(phone).font(.caption).textSelection(.enabled) }
                        }
                        .foregroundStyle(Palette.textPrimary)
                        .accessibilityElement(children: .combine)
                    }
                    PartnerActionButtons(partner: partner, actions: actions, isCompact: false)
                        .padding(.top, Spacing.xs)
                    SocialLinksRow(links: partner.socialLinks, open: actions.open)
                }
                .padding(Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle(partner.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .tint(Palette.brandPrimaryStrong)
        .presentationDetents([.medium, .large])
    }
}

/// Website, Contact, Donate, Wishlist, and product buttons. The full (detail) variant adds every
/// additional link and Call.
private struct PartnerActionButtons: View {
    let partner: Partner
    let actions: PartnerActions
    let isCompact: Bool

    var body: some View {
        VStack(spacing: Spacing.xs) {
            if partner.websiteURL != nil || !partner.emailContacts.isEmpty {
                HStack(spacing: Spacing.xs) {
                    if let website = partner.websiteURL {
                        Button("Visit Website") { actions.open(website) }
                            .buttonStyle(.filledAction(Palette.brandPrimary))
                    }
                    if !partner.emailContacts.isEmpty {
                        Button("Contact") { actions.contact(partner) }
                            .buttonStyle(.filledAction(Palette.partnerContact))
                    }
                }
            }
            if let donation = partner.donationURL {
                Button("Donate") { actions.open(donation) }
                    .buttonStyle(.filledAction(Palette.partnerDonation))
            }
            if let download = partner.downloadURL {
                Button {
                    actions.open(download)
                } label: {
                    if let product = partner.productName {
                        Text("Wishlist \(product)")
                    } else {
                        Text("Wishlist")
                    }
                }
                .buttonStyle(.filledAction(Palette.brandSecondary))
            }
            if let productURL = partner.productURL {
                Button {
                    actions.open(productURL)
                } label: {
                    if let product = partner.productName {
                        Text("View \(product)")
                    } else {
                        Text("View Product")
                    }
                }
                .buttonStyle(.outlinedAction)
            }
            if isCompact {
                if let link = partner.additionalLinks.first {
                    Button(link.label) { actions.open(link.url) }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Palette.brandPrimaryStrong)
                        .frame(maxWidth: .infinity, minHeight: Metrics.minimumTapTarget, alignment: .leading)
                }
            } else {
                ForEach(partner.additionalLinks, id: \.self) { link in
                    Button(link.label) { actions.open(link.url) }
                        .buttonStyle(.outlinedAction)
                }
                if let phone = partner.phoneNumber {
                    Button("Call") { actions.call(phone) }
                        .buttonStyle(.filledAction(Palette.partnerContact))
                }
            }
        }
    }
}

struct SocialLinksRow: View {
    let links: [SocialLink]
    let open: (URL) -> Void

    var body: some View {
        if !links.isEmpty {
            HStack(spacing: Spacing.xxs) {
                ForEach(links, id: \.self) { link in
                    Button {
                        open(link.url)
                    } label: {
                        if let imageName = link.platform.imageName {
                            Image(imageName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 28, height: 28)
                        } else {
                            Text(link.platform.label)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Palette.brandPrimaryStrong)
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(minWidth: Metrics.minimumTapTarget, minHeight: Metrics.minimumTapTarget)
                    .accessibilityLabel(link.platform.label)
                }
            }
        }
    }
}

struct PartnerLogo: View {
    let partner: Partner
    let size: CGFloat

    var body: some View {
        ContentImage(source: partner.logo, contentMode: .fit, placeholder: "partners")
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
            .accessibilityLabel(Text("\(partner.name) logo"))
    }
}

private struct FeaturedBadge: View {
    var body: some View {
        Text("Featured Partner")
            .font(.caption.weight(.semibold))
            .foregroundStyle(Palette.textPrimary)
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, 2)
            .background(Capsule().fill(Palette.featuredAccent))
    }
}

extension SocialLink.Platform {
    var imageName: String? {
        switch self {
        case .x: "social_media_x"
        case .linkedin: "social_media_linkedin"
        case .tiktok: "social_media_tiktok"
        case .instagram: "social_media_instragram"
        case .meta: "social_media_meta"
        case .discord: "social_media_discord"
        case .youtube: nil
        }
    }

    var label: String {
        switch self {
        case .x: "X"
        case .linkedin: "LinkedIn"
        case .tiktok: "TikTok"
        case .instagram: "Instagram"
        case .meta: "Facebook"
        case .discord: "Discord"
        case .youtube: "YouTube"
        }
    }
}
