import Foundation

/// A reminder that a virtual speaker session is about to start.
public struct MeetingReminder: Codable, Hashable, Sendable, Identifiable {
    public static let leadTime: TimeInterval = 2 * 60

    public let key: String
    public let eventID: String
    public let eventName: String?
    public let speakerID: String
    public let speakerName: String
    public let speakingTopic: String
    public let start: Date
    public let end: Date

    public var id: String { key }

    public init(key: String, eventID: String, eventName: String?, speakerID: String, speakerName: String, speakingTopic: String, start: Date, end: Date) {
        self.key = key
        self.eventID = eventID
        self.eventName = eventName
        self.speakerID = speakerID
        self.speakerName = speakerName
        self.speakingTopic = speakingTopic
        self.start = start
        self.end = end
    }

    public var triggerDate: Date { start.addingTimeInterval(-Self.leadTime) }

    public func hasEnded(at now: Date) -> Bool { now >= end }

    /// Whole minutes until the session starts, rounded up; `0` once it has started.
    public func minutesUntilStart(at now: Date) -> Int {
        let remainingMilliseconds = Int64((start.timeIntervalSince1970 - now.timeIntervalSince1970) * 1000)
        guard remainingMilliseconds > 0 else { return 0 }
        return Int((remainingMilliseconds + 59_999) / 60_000)
    }

    public static func key(eventID: String, speakerID: String, start: Date) -> String {
        "\(eventID)|\(speakerID)|\(Int64((start.timeIntervalSince1970 * 1000).rounded()))"
    }

    /// Notification title, e.g. "Ada is speaking in ~2 minutes" or "Ada is speaking now".
    public func title(at now: Date) -> String {
        let minutes = minutesUntilStart(at: now)
        switch minutes {
        case 0: return "\(speakerName) is speaking now"
        case 1: return "\(speakerName) is speaking in 1 minute"
        default: return "\(speakerName) is speaking in ~\(minutes) minutes"
        }
    }

    public static let joinHint = "Tap to join the virtual session"

    /// Notification body: the topic followed by the join hint.
    public var body: String {
        speakingTopic.isBlankText ? Self.joinHint : "\(speakingTopic)\n\(Self.joinHint)"
    }
}

/// Converts a speaker's published session times into absolute reminder times.
public enum MeetingTimeResolver {
    public static let defaultSessionLength: TimeInterval = 30 * 60

    public static func resolve(event: Event, speaker: Speaker) -> MeetingReminder? {
        guard let zoneID = speaker.timeZoneIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines), !zoneID.isEmpty,
              let zone = TimeZone(identifier: zoneID),
              let day = eventDay(event.dateText, in: zone),
              let startTime = parseTime(speaker.startTime)
        else { return nil }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        guard let start = calendar.date(from: DateComponents(
            year: day.year, month: day.month, day: day.day, hour: startTime.hour, minute: startTime.minute
        )) else { return nil }

        var end = start.addingTimeInterval(defaultSessionLength)
        if let endTime = parseTime(speaker.endTime),
           var resolvedEnd = calendar.date(from: DateComponents(
               year: day.year, month: day.month, day: day.day, hour: endTime.hour, minute: endTime.minute
           )) {
            if resolvedEnd <= start, let nextDay = calendar.date(byAdding: .day, value: 1, to: resolvedEnd) {
                resolvedEnd = nextDay
            }
            end = resolvedEnd
        }

        return MeetingReminder(
            key: MeetingReminder.key(eventID: event.id, speakerID: speaker.id, start: start),
            eventID: event.id,
            eventName: event.name.isBlankText ? nil : event.name,
            speakerID: speaker.id,
            speakerName: speaker.name,
            speakingTopic: speaker.topic,
            start: start,
            end: end
        )
    }

    struct Day: Equatable {
        let year: Int
        let month: Int
        let day: Int
    }

    struct TimeOfDay: Equatable {
        let hour: Int
        let minute: Int
    }

    /// The calendar day of the event in `zone`. Dates with an offset are converted to `zone`;
    /// local date-times and plain dates are used as written.
    static func eventDay(_ text: String, in zone: TimeZone) -> Day? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = #"^(\d{4})-(\d{2})-(\d{2})(?:T(\d{2}):(\d{2})(?::(\d{2})(?:\.\d{1,9})?)?(Z|[+-]\d{2}:\d{2})?)?$"#
        guard let groups = match(pattern, in: trimmed),
              let year = Int(groups[1] ?? ""), let month = Int(groups[2] ?? ""), let day = Int(groups[3] ?? ""),
              (1...12).contains(month), (1...31).contains(day)
        else { return nil }

        let hasTime = groups[4] != nil
        if hasTime, groups[7] != nil {
            guard let start = EventStart(iso8601: trimmed) else { return nil }
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = zone
            let components = calendar.dateComponents([.year, .month, .day], from: start.date)
            guard let y = components.year, let m = components.month, let d = components.day else { return nil }
            return Day(year: y, month: m, day: d)
        }
        if hasTime {
            guard let hour = Int(groups[4] ?? ""), let minute = Int(groups[5] ?? ""), hour < 24, minute < 60 else { return nil }
        }
        return Day(year: year, month: month, day: day)
    }

    /// Parses "h:mm a", "h:mma" or "H:mm" (case-insensitive). Narrow and non-breaking spaces
    /// are treated as ordinary spaces.
    static func parseTime(_ value: String?) -> TimeOfDay? {
        guard let value else { return nil }
        let normalized = value
            .replacingOccurrences(of: "\u{202F}", with: " ")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        guard !normalized.isEmpty else { return nil }

        if let groups = match(#"^(\d{1,2}):(\d{2}) ?([AaPp][Mm])$"#, in: normalized),
           let hour = Int(groups[1] ?? ""), let minute = Int(groups[2] ?? ""),
           (1...12).contains(hour), minute < 60 {
            let isPM = groups[3]?.lowercased() == "pm"
            return TimeOfDay(hour: (hour % 12) + (isPM ? 12 : 0), minute: minute)
        }
        if let groups = match(#"^(\d{1,2}):(\d{2})$"#, in: normalized),
           let hour = Int(groups[1] ?? ""), let minute = Int(groups[2] ?? ""),
           hour < 24, minute < 60 {
            return TimeOfDay(hour: hour, minute: minute)
        }
        return nil
    }

    private static func match(_ pattern: String, in text: String) -> [String?]? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let result = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text))
        else { return nil }
        return (0..<result.numberOfRanges).map { index in
            Range(result.range(at: index), in: text).map { String(text[$0]) }
        }
    }
}

/// Reminder bookkeeping persisted between launches.
public struct MeetingReminderState: Codable, Equatable, Sendable {
    public static let firedRetention: TimeInterval = 24 * 60 * 60

    /// Delivered reminder keys mapped to the end of their session.
    public var fired: [String: Date]
    public var scheduledKeys: Set<String>
    public var notificationPermissionRequested: Bool

    public init(fired: [String: Date] = [:], scheduledKeys: Set<String> = [], notificationPermissionRequested: Bool = false) {
        self.fired = fired
        self.scheduledKeys = scheduledKeys
        self.notificationPermissionRequested = notificationPermissionRequested
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fired = (try? container.decode([String: Date].self, forKey: .fired)) ?? [:]
        scheduledKeys = (try? container.decode(Set<String>.self, forKey: .scheduledKeys)) ?? []
        notificationPermissionRequested = (try? container.decode(Bool.self, forKey: .notificationPermissionRequested)) ?? false
    }

    public func hasFired(_ key: String) -> Bool { fired[key] != nil }

    /// Records a delivery; returns `false` if the reminder was already delivered.
    public mutating func markFired(_ key: String, end: Date) -> Bool {
        guard fired[key] == nil else { return false }
        fired[key] = end
        return true
    }

    public mutating func pruneFired(now: Date) {
        let cutoff = now.addingTimeInterval(-Self.firedRetention)
        fired = fired.filter { $0.value >= cutoff }
    }
}

/// A reminder and how long to wait before delivering it.
public struct ScheduledReminder: Equatable, Sendable {
    public let reminder: MeetingReminder
    public let delay: TimeInterval
}

public struct MeetingReminderPlan: Equatable, Sendable {
    public let scheduled: [ScheduledReminder]
    /// Keys scheduled earlier that are no longer wanted.
    public let cancelledKeys: Set<String>
}

public enum MeetingReminderPlanner {
    /// Plans reminders for every upcoming, undelivered speaker session and updates `state`.
    public static func plan(events: [Event], state: inout MeetingReminderState, now: Date) -> MeetingReminderPlan {
        state.pruneFired(now: now)
        var seen = Set<String>()
        let planned = events
            .flatMap { event in event.speakers.compactMap { MeetingTimeResolver.resolve(event: event, speaker: $0) } }
            .filter { seen.insert($0.key).inserted }
            .filter { !$0.hasEnded(at: now) && !state.hasFired($0.key) }
            .map { ScheduledReminder(reminder: $0, delay: max(0, $0.triggerDate.timeIntervalSince(now))) }
        let keys = Set(planned.map(\.reminder.key))
        let cancelled = state.scheduledKeys.subtracting(keys)
        state.scheduledKeys = keys
        return MeetingReminderPlan(scheduled: planned, cancelledKeys: cancelled)
    }

    /// A reminder for `speaker` delivered after `delay`, for checking notifications in debug builds.
    public static func testReminder(eventID: String, eventName: String?, speaker: Speaker, delay: TimeInterval, now: Date) -> MeetingReminder {
        let start = now.addingTimeInterval(delay + MeetingReminder.leadTime)
        let nowMilliseconds = Int64((now.timeIntervalSince1970 * 1000).rounded())
        return MeetingReminder(
            key: "test|\(MeetingReminder.key(eventID: eventID, speakerID: speaker.id, start: start))|\(nowMilliseconds)",
            eventID: eventID,
            eventName: eventName,
            speakerID: speaker.id,
            speakerName: speaker.name,
            speakingTopic: speaker.topic,
            start: start,
            end: start.addingTimeInterval(MeetingTimeResolver.defaultSessionLength)
        )
    }
}

public enum MeetingReminderDelivery: Equatable, Sendable {
    case banner, notification, alreadyDelivered, ended

    /// Decides how a due reminder is shown and records the delivery in `state`.
    public static func decide(_ reminder: MeetingReminder, state: inout MeetingReminderState, isForeground: Bool, now: Date) -> MeetingReminderDelivery {
        if reminder.hasEnded(at: now) { return .ended }
        guard state.markFired(reminder.key, end: reminder.end) else { return .alreadyDelivered }
        return isForeground ? .banner : .notification
    }
}

/// When to ask for an App Store rating.
public enum RatingPolicy {
    public static let appOpenInterval = 20
    public static let minimumStoreRating = 4
    public static let maximumRating = 5

    public static func shouldPromptForAppOpen(openCount: Int, hasBeenSentToStore: Bool) -> Bool {
        !hasBeenSentToStore && openCount > 0 && openCount % appOpenInterval == 0
    }

    /// Whether this answer was the one that reached the daily limit.
    public static func reachedLimitThisAnswer(countBefore: Int, countAfter: Int, limit: Int) -> Bool {
        countBefore < limit && countAfter >= limit
    }

    public static func shouldSendToStore(rating: Int) -> Bool { rating >= minimumStoreRating }
}
