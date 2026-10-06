import Foundation

/// A badge earned when a tracked count reaches its threshold.
public struct Achievement: Identifiable, Hashable, Sendable, Decodable {
    public let id: String
    public let title: String
    public let description: String
    /// Bundled badge image name.
    public let icon: String
    public let category: String
    public let points: Int
    public let threshold: Int
    public let trackingKey: String
    public let requirements: String

    /// Badge shown when an achievement's own image is missing.
    public static let fallbackIcon = "badge_first_step"

    public init(
        id: String, title: String, description: String, icon: String, category: String,
        points: Int, threshold: Int, trackingKey: String, requirements: String
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.icon = icon
        self.category = category
        self.points = points
        self.threshold = threshold
        self.trackingKey = trackingKey
        self.requirements = requirements
    }

    enum CodingKeys: String, CodingKey {
        case id, title, description, icon, category, points, threshold, trackingKey, requirements
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        icon = try container.decodeIfPresent(String.self, forKey: .icon)?.nonBlank ?? Self.fallbackIcon
        category = try container.decodeIfPresent(String.self, forKey: .category) ?? ""
        points = try container.decodeIfPresent(Int.self, forKey: .points) ?? 0
        threshold = try container.decodeIfPresent(Int.self, forKey: .threshold) ?? 1
        trackingKey = try container.decodeIfPresent(String.self, forKey: .trackingKey) ?? ""
        requirements = try container.decodeIfPresent(String.self, forKey: .requirements) ?? ""
    }

    public static func decodeList(from data: Data) throws -> [Achievement] {
        try JSONDecoder().decode([Achievement].self, from: data)
    }
}

/// Tracking keys used by achievements.
public enum AchievementKey {
    public static let challengeCompletion = "CHALLENGE_COMPLETION"
    public static let qrScan = "QR_SCAN"
    public static let connectionMade = "CONNECTION_MADE"
    public static let donation = "DONATION"
    public static let gameDetailsViewed = CounterKey.gameDetailsViewed
    public static let jobApplyClicked = CounterKey.jobApplyClicked
}

/// Current counts for every tracking key.
public struct AchievementProgress: Equatable, Sendable {
    public let counts: [String: Int]

    public init(counts: [String: Int]) {
        self.counts = counts
    }

    /// Engagement counters plus counts derived from the timeline.
    public init(data: LocalData) {
        var counts = data.counters
        counts[AchievementKey.challengeCompletion] = data.timeline.count { $0.type == .challengeCompletion }
        counts[AchievementKey.qrScan] = data.timeline.count { $0.type == .qrScan }
        counts[AchievementKey.connectionMade] = data.timeline.count { $0.type == .connectionMade || $0.type == .friendAdd }
        counts[AchievementKey.donation] = data.timeline.count { $0.type == .donation }
        self.counts = counts
    }

    public func count(for key: String) -> Int { counts[key] ?? 0 }

    public func isUnlocked(_ achievement: Achievement) -> Bool {
        count(for: achievement.trackingKey) >= achievement.threshold
    }

    public func unlockedCount(_ achievements: [Achievement]) -> Int {
        achievements.count(where: isUnlocked)
    }
}

/// Activity periods offered on the timeline screen.
public enum TimelineFilter: String, CaseIterable, Hashable, Sendable {
    case today, week, month

    /// Start of the period ending at `now`: the last 24 hours, 7 days, or 30 days.
    public func start(from now: Date) -> Date {
        let hours: Double = switch self {
        case .today: 24
        case .week: 24 * 7
        case .month: 24 * 30
        }
        return now.addingTimeInterval(-hours * 3600)
    }
}

/// Everything the stats screen shows.
public struct StatsSummary: Equatable, Sendable {
    public let eventsAttended: Int
    public let challengesCompleted: Int
    public let qrScans: Int
    public let questionsAnswered: Int
    public let correctAnswers: Int
    public let percentCorrect: Int
    public let currentStreak: Int
    public let achievementsUnlocked: Int
    /// Completions per category, in `ChallengeCompletion.statsCategories` order.
    public let categoryCounts: [(category: String, count: Int)]

    public static func == (lhs: StatsSummary, rhs: StatsSummary) -> Bool {
        lhs.eventsAttended == rhs.eventsAttended && lhs.challengesCompleted == rhs.challengesCompleted
            && lhs.qrScans == rhs.qrScans && lhs.questionsAnswered == rhs.questionsAnswered
            && lhs.correctAnswers == rhs.correctAnswers && lhs.percentCorrect == rhs.percentCorrect
            && lhs.currentStreak == rhs.currentStreak && lhs.achievementsUnlocked == rhs.achievementsUnlocked
            && lhs.categoryCounts.map(\.category) == rhs.categoryCounts.map(\.category)
            && lhs.categoryCounts.map(\.count) == rhs.categoryCounts.map(\.count)
    }

    public init(data: LocalData, achievements: [Achievement], calendar: Calendar) {
        let timeline = data.timeline
        eventsAttended = timeline.count { $0.type == .eventRegistration }
        let completions = timeline.filter { $0.type == .challengeCompletion }
        challengesCompleted = completions.count
        qrScans = timeline.count { $0.type == .qrScan }
        questionsAnswered = data.answerEvents.count
        correctAnswers = data.answerEvents.count(where: \.isCorrect)
        percentCorrect = questionsAnswered == 0 ? 0 : Int(Double(correctAnswers) / Double(questionsAnswered) * 100)
        currentStreak = StreakCalculator.currentStreak(answerDates: data.answerEvents.map(\.timestamp), calendar: calendar)
        achievementsUnlocked = AchievementProgress(data: data).unlockedCount(achievements)
        let counts = ChallengeCompletion.categoryCounts(completions)
        categoryCounts = ChallengeCompletion.statsCategories.map { ($0, counts[$0] ?? 0) }
    }

    /// Whether any activity has been recorded yet.
    public var hasActivity: Bool {
        eventsAttended > 0 || challengesCompleted > 0 || qrScans > 0 || achievementsUnlocked > 0 || questionsAnswered > 0
    }
}
