import Foundation

/// Event as returned by the API.
public struct EventDTO: Decodable, Sendable, Equatable {
    public var id: String
    public var name: String?
    public var host: String?
    /// ISO-8601 start time.
    public var date: String?
    public var durationHours: Int?
    public var location: String?
    /// Remote URL, bundled image name, or `color://<name>`.
    public var featuredImage: String?
    public var lumaUrl: String?
    public var virtualSpeakers: [SpeakerDTO]

    private enum CodingKeys: String, CodingKey {
        case id, name, host, date, durationHours, location, featuredImage, lumaUrl, virtualSpeakers
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIdentifier(forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        host = try container.decodeIfPresent(String.self, forKey: .host)
        date = try container.decodeIfPresent(String.self, forKey: .date)
        durationHours = try container.decodeIfPresent(Int.self, forKey: .durationHours)
        location = try container.decodeIfPresent(String.self, forKey: .location)
        featuredImage = try container.decodeIfPresent(String.self, forKey: .featuredImage)
        lumaUrl = try container.decodeIfPresent(String.self, forKey: .lumaUrl)
        virtualSpeakers = try container.decodeArray(SpeakerDTO.self, forKey: .virtualSpeakers)
    }
}

public struct SpeakerDTO: Decodable, Sendable, Equatable {
    public var id: String
    public var name: String?
    public var companyName: String?
    public var profileImage: String?
    public var description: String?
    public var speakingTopic: String?
    public var speakingSchedule: String?
    public var startTime: String?
    public var endTime: String?
    public var timeZone: String?
    public var meetUrl: String?
    public var sortOrder: Int

    private enum CodingKeys: String, CodingKey {
        case id, name, companyName, profileImage, description, speakingTopic, speakingSchedule
        case startTime, endTime, timeZone, meetUrl, sortOrder
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIdentifier(forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        companyName = try container.decodeIfPresent(String.self, forKey: .companyName)
        profileImage = try container.decodeIfPresent(String.self, forKey: .profileImage)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        speakingTopic = try container.decodeIfPresent(String.self, forKey: .speakingTopic)
        speakingSchedule = try container.decodeIfPresent(String.self, forKey: .speakingSchedule)
        startTime = try container.decodeIfPresent(String.self, forKey: .startTime)
        endTime = try container.decodeIfPresent(String.self, forKey: .endTime)
        timeZone = try container.decodeIfPresent(String.self, forKey: .timeZone)
        meetUrl = try container.decodeIfPresent(String.self, forKey: .meetUrl)
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
    }
}

public struct PartnerDTO: Decodable, Sendable, Equatable {
    public var id: String
    public var name: String?
    /// API value such as `"Game Studios"`; bundled JSON uses `"Game Studio Partners"`.
    public var category: String?
    public var logo: String?
    public var description: String?
    public var featured: Bool
    public var contacts: [ContactDTO]
    public var websiteUrl: String?
    public var additionalLinks: [LinkDTO]
    public var donationUrl: String?
    public var socialLinks: SocialLinksDTO?
    public var productName: String?
    public var productUrl: String?
    public var downloadUrl: String?

    public struct ContactDTO: Decodable, Sendable, Equatable {
        public var name: String?
        public var title: String?
        public var email: String?
        public var phone: String?
    }

    public struct LinkDTO: Decodable, Sendable, Equatable {
        public var label: String?
        public var url: String?
    }

    public struct SocialLinksDTO: Decodable, Sendable, Equatable {
        public var x: String?
        public var linkedin: String?
        public var tiktok: String?
        public var instagram: String?
        public var meta: String?
        public var discord: String?
        public var youtube: String?
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, category, logo, description, featured, contacts, websiteUrl, additionalLinks
        case donationUrl, socialLinks, productName, productUrl, downloadUrl
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIdentifier(forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        logo = try container.decodeIfPresent(String.self, forKey: .logo)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        featured = try container.decodeIfPresent(Bool.self, forKey: .featured) ?? false
        contacts = try container.decodeArray(ContactDTO.self, forKey: .contacts)
        websiteUrl = try container.decodeIfPresent(String.self, forKey: .websiteUrl)
        additionalLinks = try container.decodeArray(LinkDTO.self, forKey: .additionalLinks)
        donationUrl = try container.decodeIfPresent(String.self, forKey: .donationUrl)
        socialLinks = try container.decodeIfPresent(SocialLinksDTO.self, forKey: .socialLinks)
        productName = try container.decodeIfPresent(String.self, forKey: .productName)
        productUrl = try container.decodeIfPresent(String.self, forKey: .productUrl)
        downloadUrl = try container.decodeIfPresent(String.self, forKey: .downloadUrl)
    }
}

struct EventsPayload: Decodable {
    let events: [EventDTO]?
}

struct EventPayload: Decodable {
    let event: EventDTO?
}

struct SpeakersPayload: Decodable {
    let speakers: [SpeakerDTO]?
}

struct PartnersPayload: Decodable {
    let partners: [PartnerDTO]?
}

struct PartnerPayload: Decodable {
    let partner: PartnerDTO?
}
