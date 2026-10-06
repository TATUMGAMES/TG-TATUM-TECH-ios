import Foundation

/// Events, speakers, and partners for the UI, mapped from the API's wire models.
public protocol ContentRepository: Sendable {
    /// Upcoming events, soonest first.
    func upcomingEvents() async throws -> [Event]
    /// Speakers for an event in speaking order.
    func speakers(forEventID eventID: String) async throws -> [Speaker]
    func partners() async throws -> [Partner]
}

/// `ContentRepository` backed by the Tatum Tech API (live, or bundled JSON in local mode).
public struct APIContentRepository: ContentRepository {
    private let client: TatumTechAPIClient

    public init(client: TatumTechAPIClient) {
        self.client = client
    }

    public func upcomingEvents() async throws -> [Event] {
        try await client.upcomingEvents()
            .map(Event.init(dto:))
            .sorted(by: Self.soonestFirst)
    }

    public func speakers(forEventID eventID: String) async throws -> [Speaker] {
        try await client.eventSpeakers(eventID: eventID)
            .map(Speaker.init(dto:))
            .inSpeakingOrder()
    }

    public func partners() async throws -> [Partner] {
        try await client.partners().map(Partner.init(dto:))
    }

    /// Dated events by start time; undated events last, by name.
    static func soonestFirst(_ lhs: Event, _ rhs: Event) -> Bool {
        switch (lhs.start?.date, rhs.start?.date) {
        case let (left?, right?): left < right
        case (.some, .none): true
        case (.none, .some): false
        case (.none, .none): lhs.name < rhs.name
        }
    }
}
