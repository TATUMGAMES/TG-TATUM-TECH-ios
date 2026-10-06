import Foundation

/// Everything the app stores on this device about the user's own activity.
///
/// Persisted as one JSON document by `PersistentStore`. Missing keys decode to empty values so
/// older files keep loading after fields are added.
public struct LocalData: Codable, Equatable, Sendable {
    public var user: LocalUser?
    public var demographics: DemographicInfo?
    public var timeline: [TimelineEntry]
    public var nextTimelineID: Int64
    public var quizProgress: [String: QuizProgress]
    public var answerEvents: [QuizAnswerEvent]
    public var counters: [String: Int]
    public var contactCard: ContactCard?
    public var connections: [Connection]
    public var notifications: [RecentNotification]

    public init(
        user: LocalUser? = nil,
        demographics: DemographicInfo? = nil,
        timeline: [TimelineEntry] = [],
        nextTimelineID: Int64 = 1,
        quizProgress: [String: QuizProgress] = [:],
        answerEvents: [QuizAnswerEvent] = [],
        counters: [String: Int] = [:],
        contactCard: ContactCard? = nil,
        connections: [Connection] = [],
        notifications: [RecentNotification] = []
    ) {
        self.user = user
        self.demographics = demographics
        self.timeline = timeline
        self.nextTimelineID = nextTimelineID
        self.quizProgress = quizProgress
        self.answerEvents = answerEvents
        self.counters = counters
        self.contactCard = contactCard
        self.connections = connections
        self.notifications = notifications
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        user = try container.decodeIfPresent(LocalUser.self, forKey: .user)
        demographics = try container.decodeIfPresent(DemographicInfo.self, forKey: .demographics)
        timeline = try container.decodeIfPresent([TimelineEntry].self, forKey: .timeline) ?? []
        nextTimelineID = try container.decodeIfPresent(Int64.self, forKey: .nextTimelineID)
            ?? ((timeline.map(\.id).max() ?? 0) + 1)
        quizProgress = try container.decodeIfPresent([String: QuizProgress].self, forKey: .quizProgress) ?? [:]
        answerEvents = try container.decodeIfPresent([QuizAnswerEvent].self, forKey: .answerEvents) ?? []
        counters = try container.decodeIfPresent([String: Int].self, forKey: .counters) ?? [:]
        contactCard = try container.decodeIfPresent(ContactCard.self, forKey: .contactCard)
        connections = try container.decodeIfPresent([Connection].self, forKey: .connections) ?? []
        notifications = try container.decodeIfPresent([RecentNotification].self, forKey: .notifications) ?? []
    }
}

/// The local profile. There is exactly one; it is created anonymously on first use.
public struct LocalUser: Codable, Equatable, Sendable {
    public static let localID: Int64 = 1

    public var id: Int64
    /// `anon_` followed by six digits; identifies the user's own contact card.
    public var anonymousID: String
    public var firstName: String?
    public var lastName: String?
    /// Username shown read-only on the profile screen.
    public var name: String
    public var email: String?

    public init(
        id: Int64 = LocalUser.localID,
        anonymousID: String,
        firstName: String? = nil,
        lastName: String? = nil,
        name: String,
        email: String? = nil
    ) {
        self.id = id
        self.anonymousID = anonymousID
        self.firstName = firstName
        self.lastName = lastName
        self.name = name
        self.email = email
    }

    /// "First Last", the first name alone, or the anonymous id.
    public var displayNameOrAnonymous: String {
        let first = firstName?.nonBlank
        let last = lastName?.nonBlank
        switch (first, last) {
        case let (first?, last?): return "\(first) \(last)"
        case let (first?, nil): return first
        default: return anonymousID
        }
    }

    /// A new anonymous user, e.g. `anon_482913`.
    public static func anonymous<G: RandomNumberGenerator>(using generator: inout G) -> LocalUser {
        let id = "anon_\(Int.random(in: 100_000...999_999, using: &generator))"
        return LocalUser(anonymousID: id, name: id)
    }
}

/// Optional demographic answers. Empty strings mean "not answered".
public struct DemographicInfo: Codable, Equatable, Sendable {
    public var ageRange: String
    public var sex: String
    public var occupation: String
    public var salaryRange: String
    public var school: String

    public init(ageRange: String = "", sex: String = "", occupation: String = "", salaryRange: String = "", school: String = "") {
        self.ageRange = ageRange
        self.sex = sex
        self.occupation = occupation
        self.salaryRange = salaryRange
        self.school = school
    }

    public static let ageRanges = ["13–17", "18–24", "25–34", "35–44", "45–54", "55–64", "65+"]
    public static let sexOptions = ["Male", "Female", "Prefer Not To Say"]
    public static let salaryRanges = [
        "Under $25,000", "$25,000 - $49,999", "$50,000 - $74,999", "$75,000 - $99,999",
        "$100,000 - $149,999", "$150,000 - $199,999", "$200,000+"
    ]
}

/// Kinds of activity recorded on the timeline. Raw values are stable storage keys.
public enum TimelineType: String, Codable, CaseIterable, Sendable {
    case eventRegistration = "event_registration"
    case eventUnregistration = "event_unregistration"
    case challengeCompletion = "challenge_completion"
    case qrScan = "qr_scan"
    case friendAdd = "friend_add"
    case friendRemove = "friend_remove"
    case contactCardCreated = "contact_card_created"
    case contactCardShared = "contact_card_shared"
    case connectionMade = "connection_made"
    case donation
}

/// One recorded activity.
public struct TimelineEntry: Codable, Equatable, Identifiable, Sendable {
    public let id: Int64
    public let type: TimelineType
    public let description: String
    public let relatedID: Int64?
    public let timestamp: Date

    public init(id: Int64, type: TimelineType, description: String, relatedID: Int64? = nil, timestamp: Date) {
        self.id = id
        self.type = type
        self.description = description
        self.relatedID = relatedID
        self.timestamp = timestamp
    }
}

/// Saved state of one quiz bucket (track + language + level).
public struct QuizProgress: Codable, Equatable, Sendable {
    public var id: String
    public var quizRoute: String
    public var language: String
    public var level: String
    public var currentIndex: Int
    /// Chosen answer text by question id.
    public var answers: [String: String]
    public var questionIDs: [String]
    /// Display order of each question's options, so a resumed session looks the same.
    public var optionOrder: [String: [String]]
    public var isCompleted: Bool
    public var lastUpdated: Date

    public init(
        id: String,
        quizRoute: String,
        language: String,
        level: String,
        currentIndex: Int,
        answers: [String: String],
        questionIDs: [String],
        optionOrder: [String: [String]] = [:],
        isCompleted: Bool,
        lastUpdated: Date
    ) {
        self.id = id
        self.quizRoute = quizRoute
        self.language = language
        self.level = level
        self.currentIndex = currentIndex
        self.answers = answers
        self.questionIDs = questionIDs
        self.optionOrder = optionOrder
        self.isCompleted = isCompleted
        self.lastUpdated = lastUpdated
    }
}

/// One submitted answer; used for the daily limit, streaks, and accuracy stats.
public struct QuizAnswerEvent: Codable, Equatable, Sendable {
    public let quizRoute: String
    public let language: String
    public let level: String
    public let questionID: String
    public let answerChosen: String
    public let isCorrect: Bool
    public let timestamp: Date

    public init(quizRoute: String, language: String, level: String, questionID: String, answerChosen: String, isCorrect: Bool, timestamp: Date) {
        self.quizRoute = quizRoute
        self.language = language
        self.level = level
        self.questionID = questionID
        self.answerChosen = answerChosen
        self.isCorrect = isCorrect
        self.timestamp = timestamp
    }
}

/// Keys of `LocalData.counters`.
public enum CounterKey {
    public static let appOpenCount = "APP_OPEN_COUNT"
    public static let sentToAppStoreForRating = "HAS_BEEN_SENT_TO_APP_STORE_FOR_RATING"
    public static let gameDetailsViewed = "GAME_DETAILS_VIEWED"
    public static let jobApplyClicked = "JOB_APPLY_CLICKED"
}
