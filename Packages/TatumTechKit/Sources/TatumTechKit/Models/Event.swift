import Foundation

/// An upcoming Tatum Tech event. RSVP happens externally on Luma; registration is not tracked in-app.
public struct Event: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let host: String
    public let start: EventStart?
    public let durationHours: Int
    public let location: String
    public let featuredImage: ImageSource
    public let registrationURL: URL?
    public let speakers: [Speaker]
    /// The event date exactly as published, used to place speaker sessions on the calendar.
    public let dateText: String

    public init(
        id: String,
        name: String,
        host: String,
        start: EventStart?,
        durationHours: Int,
        location: String,
        featuredImage: ImageSource,
        registrationURL: URL?,
        speakers: [Speaker],
        dateText: String = ""
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.start = start
        self.durationHours = durationHours
        self.location = location
        self.featuredImage = featuredImage
        self.registrationURL = registrationURL
        self.speakers = speakers.inSpeakingOrder()
        self.dateText = dateText
    }

    public var hasVirtualSpeakers: Bool { !speakers.isEmpty }
    public var canRegister: Bool { registrationURL != nil }
}

/// The start of an event as written by the content: the instant plus the UTC offset it was written in.
///
/// Event times are shown in the offset they were published with rather than converted to the
/// device's time zone, matching the Android app.
public struct EventStart: Hashable, Sendable {
    public let date: Date
    public let timeZone: TimeZone

    public init(date: Date, timeZone: TimeZone) {
        self.date = date
        self.timeZone = timeZone
    }

    /// Parses ISO-8601 text such as `2026-10-10T11:30:00Z` or `2026-10-10T11:30:00-07:00`.
    public init?(iso8601 text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let date = Self.parseDate(trimmed), let offset = Self.offsetSeconds(trimmed),
              let timeZone = TimeZone(secondsFromGMT: offset)
        else { return nil }
        self.date = date
        self.timeZone = timeZone
    }

    private static func parseDate(_ text: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: text) { return date }
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: text)
    }

    private static func offsetSeconds(_ text: String) -> Int? {
        if text.uppercased().hasSuffix("Z") { return 0 }
        let suffix = text.suffix(6)
        guard suffix.count == 6, let sign = suffix.first, sign == "+" || sign == "-" else { return nil }
        let parts = suffix.dropFirst().split(separator: ":")
        guard parts.count == 2, let hours = Int(parts[0]), let minutes = Int(parts[1]) else { return nil }
        let seconds = hours * 3600 + minutes * 60
        return sign == "-" ? -seconds : seconds
    }
}

/// A virtual speaker session attached to an event.
public struct Speaker: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let companyName: String?
    public let image: ImageSource
    public let bio: String?
    public let topic: String
    public let schedule: String?
    public let startTime: String?
    public let endTime: String?
    /// IANA identifier of the zone the session times are written in, e.g. `America/Los_Angeles`.
    public let timeZoneIdentifier: String?
    public let meetURL: URL?
    public let sortOrder: Int

    public init(
        id: String,
        name: String,
        companyName: String? = nil,
        image: ImageSource = .none,
        bio: String? = nil,
        topic: String,
        schedule: String? = nil,
        startTime: String? = nil,
        endTime: String? = nil,
        timeZoneIdentifier: String? = nil,
        meetURL: URL? = nil,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.companyName = companyName
        self.image = image
        self.bio = bio
        self.topic = topic
        self.schedule = schedule
        self.startTime = startTime
        self.endTime = endTime
        self.timeZoneIdentifier = timeZoneIdentifier
        self.meetURL = meetURL
        self.sortOrder = sortOrder
    }

    public var canJoin: Bool { meetURL != nil }
}

extension Array where Element == Speaker {
    /// Speakers in the order the event runs them.
    public func inSpeakingOrder() -> [Speaker] {
        sorted { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
            return (lhs.startTime ?? "") < (rhs.startTime ?? "")
        }
    }
}

extension Event {
    init(dto: EventDTO) {
        self.init(
            id: dto.id,
            name: dto.name ?? "",
            host: dto.host ?? "",
            start: dto.date.flatMap(EventStart.init(iso8601:)),
            durationHours: dto.durationHours ?? 0,
            location: dto.location ?? "",
            featuredImage: ImageSource(contentValue: dto.featuredImage),
            registrationURL: URL(contentValue: dto.lumaUrl),
            speakers: dto.virtualSpeakers.map(Speaker.init(dto:)),
            dateText: dto.date ?? ""
        )
    }
}

extension Speaker {
    init(dto: SpeakerDTO) {
        self.init(
            id: dto.id,
            name: dto.name ?? "",
            companyName: dto.companyName?.nonBlank,
            image: ImageSource(contentValue: dto.profileImage),
            bio: dto.description?.nonBlank,
            topic: dto.speakingTopic ?? "",
            schedule: dto.speakingSchedule?.nonBlank,
            startTime: dto.startTime?.nonBlank,
            endTime: dto.endTime?.nonBlank,
            timeZoneIdentifier: dto.timeZone?.nonBlank,
            meetURL: URL(contentValue: dto.meetUrl),
            sortOrder: dto.sortOrder
        )
    }
}
