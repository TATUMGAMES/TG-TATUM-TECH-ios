import Foundation

public enum SaveConnectionResult: Equatable, Sendable {
    case created(Connection)
    case updated(Connection)

    public var connection: Connection {
        switch self {
        case .created(let connection), .updated(let connection): connection
        }
    }
}

extension LocalRepository {
    // MARK: Contact card

    public func contactCard() async -> ContactCard? {
        await store.read { $0.contactCard }
    }

    public func saveContactCard(_ card: ContactCard) async {
        await store.update { $0.contactCard = card }
    }

    // MARK: Connections

    /// Saves a scanned card. Re-scanning a known card updates its details but keeps the
    /// original connection date.
    @discardableResult
    public func saveOrUpdateConnection(_ connection: Connection) async -> SaveConnectionResult {
        await store.update { data in
            if let index = data.connections.firstIndex(where: {
                $0.ownerUserID == connection.ownerUserID && $0.connectedCardID == connection.connectedCardID
            }) {
                var updated = connection
                updated.connectedAt = data.connections[index].connectedAt
                data.connections[index] = updated
                return .updated(updated)
            }
            data.connections.append(connection)
            return .created(connection)
        }
    }

    public func connection(ownerUserID: Int64, cardID: String) async -> Connection? {
        await store.read { data in
            data.connections.first { $0.ownerUserID == ownerUserID && $0.connectedCardID == cardID }
        }
    }

    /// Connections, most recent first.
    public func connections(ownerUserID: Int64) async -> [Connection] {
        await store.read { data in
            data.connections.filter { $0.ownerUserID == ownerUserID }.sorted { $0.connectedAt > $1.connectedAt }
        }
    }

    // MARK: Recent notifications

    /// Adds today's notifications that are missing, drops read ones past retention, and returns
    /// the list newest first.
    public func refreshNotifications(events: [Event], hasChallengeQuestions: Bool, now: Date = Date(), calendar: Calendar = .current) async -> [RecentNotification] {
        await store.update { data in
            RecentNotificationPolicy.refresh(&data.notifications, events: events, hasChallengeQuestions: hasChallengeQuestions, now: now, calendar: calendar)
            return data.notifications.sorted { $0.createdAt > $1.createdAt }
        }
    }

    public func markNotificationRead(id: String, at now: Date = Date()) async {
        await store.update { data in
            guard let index = data.notifications.firstIndex(where: { $0.id == id }), data.notifications[index].readAt == nil else { return }
            data.notifications[index].readAt = now
        }
    }
}

/// Which notifications Home shows and how long they are kept.
public enum RecentNotificationPolicy {
    public static let readRetention: TimeInterval = 14 * 24 * 60 * 60
    public static let maxEventNotifications = 3

    public static func codingChallengeDailyID(_ dayKey: String) -> String { "coding_challenge:daily:\(dayKey)" }
    public static func eventID(_ eventID: String) -> String { "event:\(eventID)" }
    public static func careerSpotlightID(_ dayKey: String) -> String { "career:spotlight:\(dayKey)" }
    public static func communitySpotlightID(_ dayKey: String) -> String { "community:spotlight:\(dayKey)" }
    public static func gameSpotlightID(_ dayKey: String) -> String { "game:spotlight:\(dayKey)" }

    /// Unread notifications are always kept; read ones for 14 days.
    public static func shouldRetain(_ notification: RecentNotification, now: Date) -> Bool {
        guard let readAt = notification.readAt else { return true }
        return now.timeIntervalSince(readAt) <= readRetention
    }

    /// `yyyy-MM-dd` in the calendar's time zone.
    public static func dayKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0, month = components.month ?? 0, day = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    static func refresh(_ notifications: inout [RecentNotification], events: [Event], hasChallengeQuestions: Bool, now: Date, calendar: Calendar) {
        let dayKey = dayKey(for: now, calendar: calendar)

        func insertIfMissing(_ notification: RecentNotification) {
            guard !notifications.contains(where: { $0.id == notification.id }) else { return }
            notifications.append(notification)
        }

        if hasChallengeQuestions {
            insertIfMissing(RecentNotification(
                id: codingChallengeDailyID(dayKey), type: .codingChallenge, title: "Coding Challenge",
                description: "New coding challenge available", iconName: "notif_coding_challenge",
                createdAt: now, relatedContentID: dayKey
            ))
        }
        for event in events.prefix(maxEventNotifications) {
            insertIfMissing(RecentNotification(
                id: eventID(event.id), type: .event, title: "Upcoming Events", description: event.name,
                iconName: "upcoming_events", createdAt: now, relatedContentID: event.id
            ))
        }
        insertIfMissing(RecentNotification(
            id: careerSpotlightID(dayKey), type: .career, title: "Apply for Jobs",
            description: "New roles are available in Career. Explore openings that match your skills.",
            iconName: "jobs", createdAt: now
        ))
        insertIfMissing(RecentNotification(
            id: communitySpotlightID(dayKey), type: .community, title: "Community",
            description: "See what’s happening in the Tatum Tech community.",
            iconName: "community", createdAt: now
        ))
        insertIfMissing(RecentNotification(
            id: gameSpotlightID(dayKey), type: .game, title: "Discover",
            description: "Discover games and opportunities in the Games section.",
            iconName: "games", createdAt: now
        ))

        notifications.removeAll { !shouldRetain($0, now: now) }
    }
}
