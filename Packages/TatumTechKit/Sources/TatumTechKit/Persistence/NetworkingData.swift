import Foundation

/// The user's own Tatum Tech contact card.
public struct ContactCard: Codable, Equatable, Sendable {
    public var cardID: String
    public var ownerUserID: Int64
    /// File name of the profile photo inside the app's contact-card image directory.
    public var profileImageFileName: String?
    public var name: String
    public var jobTitle: String?
    public var company: String?
    public var description: String?
    public var email: String?
    public var phone: String?
    public var alternateEmail: String?
    public var website: String?
    public var linkedin: String?
    public var twitter: String?
    public var customLink: String?
    public var calendly: String?
    public var updatedAt: Date

    public init(
        cardID: String,
        ownerUserID: Int64,
        profileImageFileName: String? = nil,
        name: String,
        jobTitle: String? = nil,
        company: String? = nil,
        description: String? = nil,
        email: String? = nil,
        phone: String? = nil,
        alternateEmail: String? = nil,
        website: String? = nil,
        linkedin: String? = nil,
        twitter: String? = nil,
        customLink: String? = nil,
        calendly: String? = nil,
        updatedAt: Date
    ) {
        self.cardID = cardID
        self.ownerUserID = ownerUserID
        self.profileImageFileName = profileImageFileName
        self.name = name
        self.jobTitle = jobTitle
        self.company = company
        self.description = description
        self.email = email
        self.phone = phone
        self.alternateEmail = alternateEmail
        self.website = website
        self.linkedin = linkedin
        self.twitter = twitter
        self.customLink = customLink
        self.calendly = calendly
        self.updatedAt = updatedAt
    }
}

/// Someone whose card the user scanned and saved. Unique per scanned card id.
public struct Connection: Codable, Equatable, Sendable {
    public var ownerUserID: Int64
    public var connectedCardID: String
    public var connectedUserID: Int64?
    public var connectedAt: Date
    public var name: String
    public var jobTitle: String?
    public var company: String?
    public var description: String?
    public var email: String?
    public var phone: String?
    public var alternateEmail: String?
    public var website: String?
    public var linkedin: String?
    public var twitter: String?
    public var customLink: String?
    public var calendly: String?

    public init(
        ownerUserID: Int64,
        connectedCardID: String,
        connectedUserID: Int64? = nil,
        connectedAt: Date,
        name: String,
        jobTitle: String? = nil,
        company: String? = nil,
        description: String? = nil,
        email: String? = nil,
        phone: String? = nil,
        alternateEmail: String? = nil,
        website: String? = nil,
        linkedin: String? = nil,
        twitter: String? = nil,
        customLink: String? = nil,
        calendly: String? = nil
    ) {
        self.ownerUserID = ownerUserID
        self.connectedCardID = connectedCardID
        self.connectedUserID = connectedUserID
        self.connectedAt = connectedAt
        self.name = name
        self.jobTitle = jobTitle
        self.company = company
        self.description = description
        self.email = email
        self.phone = phone
        self.alternateEmail = alternateEmail
        self.website = website
        self.linkedin = linkedin
        self.twitter = twitter
        self.customLink = customLink
        self.calendly = calendly
    }
}

/// Where a recent notification leads when tapped.
public enum NotificationDestination: String, Codable, Sendable {
    case codingChallenges
    case upcomingEvents
    case career
    case community
    case games
}

/// Source of a recent notification.
public enum RecentNotificationType: String, Codable, CaseIterable, Sendable {
    case codingChallenge = "CODING_CHALLENGE"
    case event = "EVENT"
    case career = "CAREER"
    case community = "COMMUNITY"
    case game = "GAME"

    public var destination: NotificationDestination {
        switch self {
        case .codingChallenge: .codingChallenges
        case .event: .upcomingEvents
        case .career: .career
        case .community: .community
        case .game: .games
        }
    }
}

/// One entry in Home → Recent Notifications.
public struct RecentNotification: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let type: RecentNotificationType
    public let title: String
    public let description: String
    /// Bundled image name shown beside the notification.
    public let iconName: String
    public let createdAt: Date
    public var readAt: Date?
    public let relatedContentID: String?

    public init(
        id: String,
        type: RecentNotificationType,
        title: String,
        description: String,
        iconName: String,
        createdAt: Date,
        readAt: Date? = nil,
        relatedContentID: String? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.description = description
        self.iconName = iconName
        self.createdAt = createdAt
        self.readAt = readAt
        self.relatedContentID = relatedContentID
    }

    public var isUnread: Bool { readAt == nil }
    public var destination: NotificationDestination { type.destination }
}
