import Foundation

/// A partner organization in the Tatum Tech directory. Optional details are absent when the
/// content does not provide them; never invent values.
public struct Partner: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let category: PartnerCategory
    public let logo: ImageSource
    public let summary: String?
    public let isFeatured: Bool
    public let contacts: [PartnerContact]
    public let websiteURL: URL?
    public let additionalLinks: [PartnerLink]
    public let donationURL: URL?
    public let socialLinks: [SocialLink]
    public let productName: String?
    public let productURL: URL?
    public let downloadURL: URL?

    public init(
        id: String,
        name: String,
        category: PartnerCategory,
        logo: ImageSource = .none,
        summary: String? = nil,
        isFeatured: Bool = false,
        contacts: [PartnerContact] = [],
        websiteURL: URL? = nil,
        additionalLinks: [PartnerLink] = [],
        donationURL: URL? = nil,
        socialLinks: [SocialLink] = [],
        productName: String? = nil,
        productURL: URL? = nil,
        downloadURL: URL? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.logo = logo
        self.summary = summary
        self.isFeatured = isFeatured
        self.contacts = contacts
        self.websiteURL = websiteURL
        self.additionalLinks = additionalLinks
        self.donationURL = donationURL
        self.socialLinks = socialLinks
        self.productName = productName
        self.productURL = productURL
        self.downloadURL = downloadURL
    }

    /// Contacts that can be emailed.
    public var emailContacts: [PartnerContact] { contacts.filter { $0.email != nil } }

    /// The first contact phone number, used by the Call action.
    public var phoneNumber: String? { contacts.lazy.compactMap(\.phone).first }
}

public struct PartnerContact: Hashable, Sendable {
    public let name: String
    public let title: String?
    public let email: String?
    public let phone: String?

    public init(name: String, title: String? = nil, email: String? = nil, phone: String? = nil) {
        self.name = name
        self.title = title
        self.email = email
        self.phone = phone
    }
}

public struct PartnerLink: Hashable, Sendable {
    public let label: String
    public let url: URL

    public init(label: String, url: URL) {
        self.label = label
        self.url = url
    }
}

public struct SocialLink: Hashable, Sendable {
    public enum Platform: String, CaseIterable, Sendable {
        case x, linkedin, tiktok, instagram, meta, discord, youtube
    }

    public let platform: Platform
    public let url: URL

    public init(platform: Platform, url: URL) {
        self.platform = platform
        self.url = url
    }
}

/// Partner directory category.
///
/// The API sends short values (`"Game Studios"`), the bundled JSON uses full labels
/// (`"Game Studio Partners"`); both map to the same case.
public enum PartnerCategory: Hashable, Sendable {
    case community, corporate, education, gameStudios, government, technology
    case other(String)

    /// Categories offered as filters, in display order.
    public static let filterable: [PartnerCategory] = [
        .community, .corporate, .education, .gameStudios, .government, .technology
    ]

    public init(contentValue: String?) {
        let value = contentValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let match = Self.filterable.first { category in
            value.caseInsensitiveCompare(category.shortName) == .orderedSame
                || value.caseInsensitiveCompare(category.fullName) == .orderedSame
        }
        self = match ?? .other(value)
    }

    /// Concise label used on filter chips and cards.
    public var shortName: String {
        switch self {
        case .community: "Community"
        case .corporate: "Corporate"
        case .education: "Education"
        case .gameStudios: "Game Studios"
        case .government: "Government"
        case .technology: "Technology"
        case .other(let value): value
        }
    }

    /// Full label used in partner details.
    public var fullName: String {
        switch self {
        case .community: "Community Partners"
        case .corporate: "Corporate Partners"
        case .education: "Education Partners"
        case .gameStudios: "Game Studio Partners"
        case .government: "Government Partners"
        case .technology: "Technology Partners"
        case .other(let value): value
        }
    }
}

public enum PartnerDirectory {
    /// Partners in `category` (all when `nil`), featured partners first, then by name.
    public static func filter(_ partners: [Partner], category: PartnerCategory?) -> [Partner] {
        partners
            .filter { category == nil || $0.category == category }
            .sorted { lhs, rhs in
                if lhs.isFeatured != rhs.isFeatured { return lhs.isFeatured }
                return lhs.name.lowercased() < rhs.name.lowercased()
            }
    }
}

extension Partner {
    init(dto: PartnerDTO) {
        let social = dto.socialLinks
        let socialValues: [(SocialLink.Platform, String?)] = [
            (.x, social?.x), (.linkedin, social?.linkedin), (.tiktok, social?.tiktok),
            (.instagram, social?.instagram), (.meta, social?.meta), (.discord, social?.discord),
            (.youtube, social?.youtube)
        ]
        self.init(
            id: dto.id,
            name: dto.name ?? "",
            category: PartnerCategory(contentValue: dto.category),
            logo: ImageSource(contentValue: dto.logo),
            summary: dto.description?.nonBlank,
            isFeatured: dto.featured,
            contacts: dto.contacts.map {
                PartnerContact(
                    name: $0.name ?? "",
                    title: $0.title?.nonBlank,
                    email: $0.email?.nonBlank,
                    phone: $0.phone?.nonBlank
                )
            },
            websiteURL: URL(contentValue: dto.websiteUrl),
            additionalLinks: dto.additionalLinks.compactMap { link in
                URL(contentValue: link.url).map { PartnerLink(label: link.label ?? "", url: $0) }
            },
            donationURL: URL(contentValue: dto.donationUrl),
            socialLinks: socialValues.compactMap { platform, value in
                URL(contentValue: value).map { SocialLink(platform: platform, url: $0) }
            },
            productName: dto.productName?.nonBlank,
            productURL: URL(contentValue: dto.productUrl),
            downloadURL: URL(contentValue: dto.downloadUrl)
        )
    }
}
