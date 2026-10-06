import Foundation

/// An image reference in the games catalog: a bundled asset or a remote URL.
public enum GameMedia: Hashable, Sendable {
    case asset(String)
    case remote(URL)

    /// `drawable:name` refers to a bundled asset; anything else is treated as a URL.
    public init?(reference: String?) {
        guard let reference = reference?.trimmingCharacters(in: .whitespacesAndNewlines), !reference.isEmpty else { return nil }
        if reference.hasPrefix("drawable:") {
            let name = String(reference.dropFirst("drawable:".count))
            guard !name.isEmpty else { return nil }
            self = .asset(name)
        } else if let url = URL(string: reference), url.scheme != nil {
            self = .remote(url)
        } else {
            return nil
        }
    }
}

public struct GameVideo: Hashable, Sendable {
    public let url: URL
    public let thumbnailURL: URL?
}

public struct GameCampaignLinks: Hashable, Sendable {
    public var googleStore: URL?
    public var appleStore: URL?
    public var steamStore: URL?
    public var other: URL?
    public var website: URL?
}

public struct GameSocialLinks: Hashable, Sendable {
    public var facebook: URL?
    public var x: URL?
    public var instagram: URL?
    public var linkedin: URL?
    public var tiktok: URL?
    public var youtube: URL?
    public var discord: URL?

    /// Links shown as icons, in display order.
    public var iconLinks: [SocialLink] {
        [
            x.map { SocialLink(platform: .x, url: $0) },
            linkedin.map { SocialLink(platform: .linkedin, url: $0) },
            tiktok.map { SocialLink(platform: .tiktok, url: $0) },
            instagram.map { SocialLink(platform: .instagram, url: $0) },
            facebook.map { SocialLink(platform: .meta, url: $0) }
        ].compactMap { $0 }
    }
}

/// A game in the Games catalog.
public struct Game: Identifiable, Hashable, Sendable {
    public let id: String
    public let appName: String
    public let companyName: String
    public let title: String
    public let shortDescription: String
    public let longDescription: String
    public let website: URL?
    public let appCategory: String
    public let appStore: String
    public let subscriptionType: String
    public let releaseStatus: String
    public let featureGraphics: [GameMedia]
    public let screenshots: [GameMedia]
    public let promotionalVideos: [GameVideo]
    public let marketingCampaignActive: Bool
    public let gameGenre: String?
    public let gameplayType: String?
    public let isFeatured: Bool
    public let featuredPriority: Int
    public let featuredStart: Date?
    public let featuredEnd: Date?
    public let popularityScore: Int
    public let discoveryTags: [String]
    public let genres: [String]
    public let logo: GameMedia?
    public let campaignLinks: GameCampaignLinks
    public let social: GameSocialLinks

    public var isComingSoon: Bool { releaseStatus.caseInsensitiveCompare("Coming Soon") == .orderedSame }
    public var isReleased: Bool { releaseStatus.caseInsensitiveCompare("Released") == .orderedSame }

    /// The large image for cards and the details header.
    public var heroImage: GameMedia? { featureGraphics.first ?? logo }

    /// Whether any store, website, or social link exists.
    public var hasOutboundLinks: Bool {
        let links: [URL?] = [
            campaignLinks.googleStore, campaignLinks.appleStore, campaignLinks.steamStore, campaignLinks.other,
            campaignLinks.website, website, social.discord, social.facebook, social.x, social.instagram,
            social.linkedin, social.tiktok, social.youtube
        ]
        return links.contains { $0 != nil }
    }

    /// Store and website buttons in display order.
    public var callsToAction: [GameCallToAction] {
        var actions: [GameCallToAction] = []
        if let url = campaignLinks.googleStore { actions.append(GameCallToAction(kind: .googlePlay, label: "Download for Android", url: url)) }
        if let url = campaignLinks.appleStore { actions.append(GameCallToAction(kind: .appStore, label: "Download for iOS", url: url)) }
        if let url = campaignLinks.steamStore {
            actions.append(GameCallToAction(kind: .steam, label: isComingSoon ? "Wishlist on Steam" : "Get it on Steam", url: url))
        }
        if let url = campaignLinks.other {
            actions.append(GameCallToAction(kind: .otherStore, label: Self.otherStoreLabel(for: url, comingSoon: isComingSoon), url: url))
        }
        if let url = campaignLinks.website ?? website {
            actions.append(GameCallToAction(kind: .website, label: "Visit Website", url: url))
        }
        return actions
    }

    static func otherStoreLabel(for url: URL, comingSoon: Bool) -> String {
        let host = (url.host ?? "").lowercased()
        let isMetaQuest = host == "meta.com" || host.hasSuffix(".meta.com") || host == "oculus.com" || host.hasSuffix(".oculus.com")
        let isLinktree = host == "linktr.ee" || host.hasSuffix(".linktr.ee")
        if isMetaQuest { return comingSoon ? "Wishlist on Meta Quest" : "Get it on Meta Quest" }
        if isLinktree { return "Visit Linktree" }
        return "View Store Page"
    }
}

public struct GameCallToAction: Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        case googlePlay, appStore, steam, otherStore, website
    }

    public let kind: Kind
    public let label: String
    public let url: URL
}

/// Search, filters, and sections of the Games catalog.
public struct GameCatalog: Sendable {
    public static let all = "All"
    public static let gameplayTypes = [all, "Casual", "Non-Casual"]

    public let games: [Game]

    public init(games: [Game]) {
        self.games = games
    }

    /// Decodes `games.json` (`{"data": {"apps": [...]}}`).
    public static func decode(_ data: Data) throws -> GameCatalog {
        let response = try JSONDecoder().decode(GamesResponseDTO.self, from: data)
        guard let apps = response.data?.apps else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Invalid catalog: missing data.apps"))
        }
        return GameCatalog(games: apps.compactMap(Game.init(dto:)))
    }

    public func game(id: String) -> Game? { games.first { $0.id == id } }

    /// "All" followed by every genre, game genre, and category in catalog order.
    public var genres: [String] {
        var seen = Set<String>()
        var result: [String] = []
        func add(_ value: String?) {
            guard let value, !value.isBlankText, seen.insert(value).inserted else { return }
            result.append(value)
        }
        add(Self.all)
        for game in games {
            game.genres.forEach(add)
            add(game.gameGenre)
            add(game.appCategory)
        }
        return result
    }

    public func filtered(query: String, genre: String?, gameplayType: String?) -> [Game] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        var list = games
        if !query.isEmpty {
            list = list.filter { game in
                [game.appName, game.title, game.shortDescription, game.longDescription].contains {
                    $0.range(of: query, options: .caseInsensitive) != nil
                }
            }
        }
        if let genre, genre != Self.all {
            list = list.filter { game in
                game.genres.contains { $0.equalsIgnoringCase(genre) }
                    || game.gameGenre?.equalsIgnoringCase(genre) == true
                    || game.appCategory.equalsIgnoringCase(genre)
            }
        }
        if let gameplayType, gameplayType != Self.all {
            list = list.filter { $0.gameplayType?.equalsIgnoringCase(gameplayType) == true }
        }
        return list
    }

    public static func sections(for games: [Game], now: Date) -> GameSections {
        let hero = games
            .filter { isHeroEligible($0, now: now) }
            .enumerated()
            .sorted { lhs, rhs in
                let left = lhs.element.isFeatured ? lhs.element.featuredPriority : 0
                let right = rhs.element.isFeatured ? rhs.element.featuredPriority : 0
                if left != right { return left > right }
                if lhs.element.popularityScore != rhs.element.popularityScore {
                    return lhs.element.popularityScore > rhs.element.popularityScore
                }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
        return GameSections(
            featured: hero,
            justTooFun: games.filter { $0.subscriptionType.equalsIgnoringCase("Enterprise") },
            tatumGamesFavorites: games.filter { $0.subscriptionType.equalsIgnoringCase("Startup") },
            appsInDevelopment: games.filter { !$0.releaseStatus.equalsIgnoringCase("Released") },
            casualGamer: games.filter { $0.subscriptionType.equalsIgnoringCase("Free") && $0.gameplayType?.equalsIgnoringCase("Casual") == true },
            coreGamer: games.filter { $0.subscriptionType.equalsIgnoringCase("Free") && $0.gameplayType?.equalsIgnoringCase("Non-Casual") == true }
        )
    }

    static func isHeroEligible(_ game: Game, now: Date) -> Bool {
        if game.isFeatured {
            if game.featuredStart == nil && game.featuredEnd == nil { return true }
            let afterStart = game.featuredStart.map { now >= $0 } ?? true
            let beforeEnd = game.featuredEnd.map { now <= $0 } ?? true
            return afterStart && beforeEnd
        }
        return game.marketingCampaignActive
    }
}

public struct GameSections: Equatable, Sendable {
    public let featured: [Game]
    public let justTooFun: [Game]
    public let tatumGamesFavorites: [Game]
    public let appsInDevelopment: [Game]
    public let casualGamer: [Game]
    public let coreGamer: [Game]

    /// Titled carousels on the Games tab, empty ones omitted.
    public var carousels: [(title: String, games: [Game])] {
        [
            ("Just Too Fun", justTooFun),
            ("Tatum Games Favorites", tatumGamesFavorites),
            ("Apps in Development", appsInDevelopment),
            ("Casual Gamer", casualGamer),
            ("Core Gamer", coreGamer)
        ].filter { !$0.1.isEmpty }
    }

    public static func == (lhs: GameSections, rhs: GameSections) -> Bool {
        lhs.featured == rhs.featured && lhs.justTooFun == rhs.justTooFun && lhs.tatumGamesFavorites == rhs.tatumGamesFavorites
            && lhs.appsInDevelopment == rhs.appsInDevelopment && lhs.casualGamer == rhs.casualGamer && lhs.coreGamer == rhs.coreGamer
    }
}

// MARK: - DTOs

struct GamesResponseDTO: Decodable {
    struct DataDTO: Decodable {
        let apps: [GameDTO]?
    }

    let data: DataDTO?
}

struct GameDTO: Decodable {
    struct Images: Decodable {
        var featureGraphics: [String]?
        var screenshots: [String]?
    }

    struct Video: Decodable {
        var url: String?
        var thumbnailUrl: String?
    }

    struct Videos: Decodable {
        var promotional: [Video]?
    }

    struct Campaign: Decodable {
        struct CampaignImages: Decodable { var appLogo: String? }
        struct CTAs: Decodable {
            var google_store: String?
            var apple_store: String?
            var steam_store: String?
            var website: String?
            var other: String?
        }
        struct Social: Decodable {
            var facebook: String?
            var x: String?
            var instagram: String?
            var linkedin: String?
            var tiktok: String?
            var youtube: String?
            var discord: String?
        }

        var images: CampaignImages?
        var ctas: CTAs?
        var socialMedia: Social?
    }

    var appId: String?
    var appName: String?
    var companyName: String?
    var title: String?
    var shortDescription: String?
    var longDescription: String?
    var website: String?
    var appCategory: String?
    var appStore: String?
    var userSubscriptionType: String?
    var releaseStatus: String?
    var images: Images?
    var videos: Videos?
    var marketingCampaignActive: Bool?
    var gameGenre: String?
    var gameplayType: String?
    var campaign: Campaign?
    var isFeatured: Bool?
    var featuredPriority: Int?
    var featuredStartDate: String?
    var featuredEndDate: String?
    var popularityScore: Int?
    var discoveryTags: [String]?
    var genres: [String]?
}

extension Game {
    init?(dto: GameDTO) {
        guard let id = dto.appId?.nonBlank else { return nil }
        let isoFormatter = ISO8601DateFormatter()
        self.init(
            id: id,
            appName: dto.appName ?? "",
            companyName: dto.companyName ?? "",
            title: dto.title ?? dto.appName ?? "",
            shortDescription: dto.shortDescription ?? "",
            longDescription: dto.longDescription ?? "",
            website: URL(contentValue: dto.website),
            appCategory: dto.appCategory ?? "",
            appStore: dto.appStore ?? "",
            subscriptionType: dto.userSubscriptionType ?? "",
            releaseStatus: dto.releaseStatus ?? "",
            featureGraphics: (dto.images?.featureGraphics ?? []).compactMap(GameMedia.init(reference:)),
            screenshots: (dto.images?.screenshots ?? []).compactMap(GameMedia.init(reference:)),
            promotionalVideos: (dto.videos?.promotional ?? []).compactMap { video in
                URL(contentValue: video.url).map { GameVideo(url: $0, thumbnailURL: URL(contentValue: video.thumbnailUrl)) }
            },
            marketingCampaignActive: dto.marketingCampaignActive ?? false,
            gameGenre: dto.gameGenre?.nonBlank,
            gameplayType: dto.gameplayType?.nonBlank,
            isFeatured: dto.isFeatured ?? false,
            featuredPriority: dto.featuredPriority ?? 0,
            featuredStart: dto.featuredStartDate.flatMap { isoFormatter.date(from: $0) },
            featuredEnd: dto.featuredEndDate.flatMap { isoFormatter.date(from: $0) },
            popularityScore: dto.popularityScore ?? 0,
            discoveryTags: dto.discoveryTags ?? [],
            genres: dto.genres ?? [],
            logo: GameMedia(reference: dto.campaign?.images?.appLogo),
            campaignLinks: GameCampaignLinks(
                googleStore: URL(contentValue: dto.campaign?.ctas?.google_store),
                appleStore: URL(contentValue: dto.campaign?.ctas?.apple_store),
                steamStore: URL(contentValue: dto.campaign?.ctas?.steam_store),
                other: URL(contentValue: dto.campaign?.ctas?.other),
                website: URL(contentValue: dto.campaign?.ctas?.website)
            ),
            social: GameSocialLinks(
                facebook: URL(contentValue: dto.campaign?.socialMedia?.facebook),
                x: URL(contentValue: dto.campaign?.socialMedia?.x),
                instagram: URL(contentValue: dto.campaign?.socialMedia?.instagram),
                linkedin: URL(contentValue: dto.campaign?.socialMedia?.linkedin),
                tiktok: URL(contentValue: dto.campaign?.socialMedia?.tiktok),
                youtube: URL(contentValue: dto.campaign?.socialMedia?.youtube),
                discord: URL(contentValue: dto.campaign?.socialMedia?.discord)
            )
        )
    }
}

extension String {
    func equalsIgnoringCase(_ other: String) -> Bool {
        caseInsensitiveCompare(other) == .orderedSame
    }
}
