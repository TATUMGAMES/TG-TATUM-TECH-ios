import Foundation

/// A job opening listed under Career.
public struct CareerListing: Identifiable, Hashable, Sendable, Decodable {
    public let id: String
    public let company: String
    public let title: String
    public let category: String
    public let employmentType: String
    public let description: String
    public let technologies: [String]
    public let applyURL: URL?

    public init(
        id: String, company: String, title: String, category: String, employmentType: String,
        description: String, technologies: [String] = [], applyURL: URL?
    ) {
        self.id = id
        self.company = company
        self.title = title
        self.category = category
        self.employmentType = employmentType
        self.description = description
        self.technologies = technologies
        self.applyURL = applyURL
    }

    enum CodingKeys: String, CodingKey {
        case id, company, title, category, employmentType, description, technologies, applyUrl
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        company = try container.decodeIfPresent(String.self, forKey: .company) ?? ""
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        category = try container.decodeIfPresent(String.self, forKey: .category) ?? ""
        employmentType = try container.decodeIfPresent(String.self, forKey: .employmentType) ?? ""
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        technologies = (try container.decodeIfPresent([LossyString].self, forKey: .technologies) ?? []).compactMap(\.value)
        applyURL = URL(contentValue: try container.decodeIfPresent(String.self, forKey: .applyUrl))
    }
}

/// Search and filters on the Career screen.
public enum CareerFilters {
    public static let all = "All"
    public static let categories = [
        all, "Software Engineering", "Game Development", "AI / Machine Learning", "Product", "Design",
        "Data / Analytics", "Graphics / Rendering", "Backend / Cloud", "Other"
    ]
    public static let employmentTypes = [all, "Full-time", "Part-time", "Contract", "Internship"]

    /// Listings in the category and employment type whose title, company, description, or
    /// technologies contain `query` (case-insensitive).
    public static func filter(_ listings: [CareerListing], query: String, category: String, employmentType: String) -> [CareerListing] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return listings.filter { listing in
            if category != all && listing.category != category { return false }
            if employmentType != all && listing.employmentType != employmentType { return false }
            guard !query.isEmpty else { return true }
            let haystack = ([listing.title, listing.company, listing.description] + listing.technologies).joined(separator: " ")
            return haystack.range(of: query, options: [.caseInsensitive]) != nil
        }
    }

    public static func isFiltering(query: String, category: String, employmentType: String) -> Bool {
        !query.isBlankText || category != all || employmentType != all
    }
}

/// A vetted learning resource.
public struct LearningResource: Identifiable, Hashable, Sendable, Decodable {
    public let id: String
    public let title: String
    public let url: URL?
    public let description: String?
    public let source: String?
    public let categories: [String]
    public let resourceType: String?

    public init(id: String, title: String, url: URL?, description: String? = nil, source: String? = nil, categories: [String] = [], resourceType: String? = nil) {
        self.id = id
        self.title = title
        self.url = url
        self.description = description
        self.source = source
        self.categories = categories
        self.resourceType = resourceType
    }

    enum CodingKeys: String, CodingKey {
        case id, title, url, description, source, categories, resourceType
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        url = URL(contentValue: try container.decodeIfPresent(String.self, forKey: .url))
        description = try container.decodeIfPresent(String.self, forKey: .description)?.nonBlank
        source = try container.decodeIfPresent(String.self, forKey: .source)?.nonBlank
        categories = (try container.decodeIfPresent([LossyString].self, forKey: .categories) ?? []).compactMap(\.value)
        resourceType = try container.decodeIfPresent(String.self, forKey: .resourceType)?.nonBlank
    }

    /// "Source · Type · Category, Category" with missing parts left out.
    public var metadataLine: String {
        var parts = [source, resourceType].compactMap { $0 }
        if !categories.isEmpty { parts.append(categories.joined(separator: ", ")) }
        return parts.joined(separator: " · ")
    }
}

/// Technology filter on the Resources screen.
public enum ResourceFilters {
    public static let all = "All"
    public static let categories = [all, "Java", "Kotlin", "C++", "C#", "Python", "AI/ML", "JavaScript", "PHP"]

    public static func filter(_ resources: [LearningResource], category: String) -> [LearningResource] {
        guard category != all else { return resources }
        return resources.filter { resource in
            resource.categories.contains { $0.caseInsensitiveCompare(category) == .orderedSame }
        }
    }
}

/// A group of partners shown under Games → Resources.
public struct GamesResourceCategory: Hashable, Sendable, Decodable {
    public let category: String
    public let partnerIDs: [String]

    public init(category: String, partnerIDs: [String]) {
        self.category = category
        self.partnerIDs = partnerIDs
    }

    enum CodingKeys: String, CodingKey {
        case category, partnerIds
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        category = try container.decodeIfPresent(String.self, forKey: .category) ?? ""
        partnerIDs = (try container.decodeIfPresent([LossyString].self, forKey: .partnerIds) ?? []).compactMap(\.value)
    }
}

/// A resolved Games → Resources section.
public struct GamesResourceSection: Hashable, Sendable {
    public let category: String
    public let partners: [Partner]
}

public enum GamesResourcesResolver {
    /// Sections with their partners looked up by id. Unknown ids are skipped; sections with no
    /// known partners are omitted.
    public static func resolve(_ categories: [GamesResourceCategory], partners: [Partner]) -> [GamesResourceSection] {
        let byID = Dictionary(partners.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return categories.compactMap { category in
            let resolved = category.partnerIDs.compactMap { byID[$0] }
            guard !category.category.isBlankText, !resolved.isEmpty else { return nil }
            return GamesResourceSection(category: category.category, partners: resolved)
        }
    }
}

/// Sponsorship tiers on the Donate screen; each opens a Stripe checkout page.
public enum DonationTier: String, CaseIterable, Identifiable, Sendable {
    case foundingSupporter, silverSponsor, goldSponsor, premierSponsor

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .foundingSupporter: "Founding Supporter"
        case .silverSponsor: "Silver Sponsor"
        case .goldSponsor: "Gold Sponsor"
        case .premierSponsor: "Premier Sponsor"
        }
    }

    public var amount: String {
        switch self {
        case .foundingSupporter: "Custom"
        case .silverSponsor: "$2,500"
        case .goldSponsor: "$5,000"
        case .premierSponsor: "$10,000"
        }
    }

    public var url: URL {
        switch self {
        case .foundingSupporter: AppLinks.stripeCustom
        case .silverSponsor: AppLinks.stripe2500
        case .goldSponsor: AppLinks.stripe5000
        case .premierSponsor: AppLinks.stripe10000
        }
    }

    /// e.g. "Gold Sponsor – $5,000".
    public var label: String { "\(name) – \(amount)" }
}

/// External destinations used across the app.
public enum AppLinks {
    public static let terms = URL(string: "https://developer.tatumgames.com/terms")!
    public static let privacy = URL(string: "https://developer.tatumgames.com/privacy")!
    public static let tatumTech = URL(string: "https://tatumgames.com/tatum-tech/")!

    public static let mikrosDeveloper = URL(string: "https://developer.tatumgames.com/")!
    public static let mikrosDocumentation = URL(string: "https://developer.tatumgames.com/documentation/introduction")!
    public static let mikrosExplainerVideo = URL(string: "https://youtu.be/pz2iMZ-mjFM")!
    public static let mikrosMarketingTutorial = URL(string: "https://youtu.be/n2a1hoINzKw")!
    public static let mikrosAnalyticsIntegration = URL(string: "https://youtu.be/4g380D_bAVA")!
    public static let mikrosAnalyticsLogging = URL(string: "https://youtu.be/GINXSVBlO0M")!

    public static let discordInviteCode = "6FzqSUDRXQ"
    public static let discordInvite = URL(string: "https://discord.com/invite/6FzqSUDRXQ")!
    public static let discordApp = URL(string: "discord://invite/6FzqSUDRXQ")!
    public static let discordInviteAPI = URL(string: "https://discord.com/api/v9/invites/6FzqSUDRXQ?with_counts=true&with_expiration=true")!
    public static let supportUs = URL(string: "https://payrole.io/app/store?id=65e729cff968f40012f47835&nojoin")!

    public static let stripeCustom = URL(string: "https://buy.stripe.com/7sI3cH8m6bmd5ck4gj")!
    public static let stripe2500 = URL(string: "https://buy.stripe.com/28oaF9cCmdul7kscMO")!
    public static let stripe5000 = URL(string: "https://buy.stripe.com/6oEbJd6dY0Hz8ow145")!
    public static let stripe10000 = URL(string: "https://buy.stripe.com/3cs28D45QgGxgV2fYY")!

    /// The App Store "write a review" page for `appStoreID`, or `nil` when no id is configured.
    public static func appStoreReview(appStoreID: String?) -> URL? {
        guard let id = appStoreID?.nonBlank, id.allSatisfy(\.isNumber) else { return nil }
        return URL(string: "https://apps.apple.com/app/id\(id)?action=write-review")
    }
}
