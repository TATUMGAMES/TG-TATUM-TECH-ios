import Foundation
import Testing
@testable import TatumTechKit

@Suite("Meeting reminders")
struct MeetingReminderTests {
    private func event(date: String, speakers: [Speaker]) -> Event {
        Event(id: "e1", name: "Tatum Tech Summit", host: "Tatum", start: EventStart(iso8601: date), durationHours: 2,
              location: "Online", featuredImage: .none, registrationURL: nil, speakers: speakers, dateText: date)
    }

    private func speaker(id: String = "s1", start: String?, end: String? = nil, zone: String? = "America/Los_Angeles") -> Speaker {
        Speaker(id: id, name: "Ada", topic: "Shaders", startTime: start, endTime: end, timeZoneIdentifier: zone)
    }

    @Test func parsesTheSupportedTimeFormats() {
        #expect(MeetingTimeResolver.parseTime("1:30 PM") == .init(hour: 13, minute: 30))
        #expect(MeetingTimeResolver.parseTime("1:30pm") == .init(hour: 13, minute: 30))
        #expect(MeetingTimeResolver.parseTime("12:05 am") == .init(hour: 0, minute: 5))
        #expect(MeetingTimeResolver.parseTime("12:05\u{202F}PM") == .init(hour: 12, minute: 5))
        #expect(MeetingTimeResolver.parseTime("17:45") == .init(hour: 17, minute: 45))
        #expect(MeetingTimeResolver.parseTime("13:00 PM") == nil)
        #expect(MeetingTimeResolver.parseTime("noon") == nil)
        #expect(MeetingTimeResolver.parseTime(nil) == nil)
    }

    @Test func resolvesSessionTimesInTheSpeakersZone() throws {
        let reminder = try #require(MeetingTimeResolver.resolve(
            event: event(date: "2026-10-10T18:00:00Z", speakers: []),
            speaker: speaker(start: "10:00 AM", end: "10:45 AM")
        ))
        // 10:00 in Los Angeles (PDT, UTC-7) on 10 October 2026.
        #expect(reminder.start == Date(timeIntervalSince1970: 1_791_651_600))
        #expect(reminder.end.timeIntervalSince(reminder.start) == 45 * 60)
        #expect(reminder.triggerDate == reminder.start.addingTimeInterval(-120))
        #expect(reminder.key == "e1|s1|1791651600000")
        #expect(reminder.eventName == "Tatum Tech Summit")
    }

    @Test func endTimesBeforeTheStartRollOverAndMissingEndsDefault() throws {
        let overnight = try #require(MeetingTimeResolver.resolve(
            event: event(date: "2026-10-10", speakers: []), speaker: speaker(start: "11:30 PM", end: "12:15 AM")
        ))
        #expect(overnight.end.timeIntervalSince(overnight.start) == 45 * 60)
        let open = try #require(MeetingTimeResolver.resolve(
            event: event(date: "2026-10-10T09:00:00", speakers: []), speaker: speaker(start: "9:00 AM")
        ))
        #expect(open.end.timeIntervalSince(open.start) == 30 * 60)
    }

    @Test func sessionsWithoutAZoneOrTimeAreSkipped() {
        #expect(MeetingTimeResolver.resolve(event: event(date: "2026-10-10", speakers: []), speaker: speaker(start: "9:00 AM", zone: nil)) == nil)
        #expect(MeetingTimeResolver.resolve(event: event(date: "2026-10-10", speakers: []), speaker: speaker(start: "9:00 AM", zone: "Not/AZone")) == nil)
        #expect(MeetingTimeResolver.resolve(event: event(date: "2026-10-10", speakers: []), speaker: speaker(start: nil)) == nil)
        #expect(MeetingTimeResolver.resolve(event: event(date: "soon", speakers: []), speaker: speaker(start: "9:00 AM")) == nil)
    }

    @Test func minutesAndTitlesRoundUp() {
        let start = Date(timeIntervalSince1970: 10_000)
        let reminder = MeetingReminder(key: "k", eventID: "e", eventName: nil, speakerID: "s", speakerName: "Ada", speakingTopic: "Shaders", start: start, end: start + 1800)
        #expect(reminder.minutesUntilStart(at: start - 61) == 2)
        #expect(reminder.minutesUntilStart(at: start - 60) == 1)
        #expect(reminder.minutesUntilStart(at: start) == 0)
        #expect(reminder.title(at: start - 120) == "Ada is speaking in ~2 minutes")
        #expect(reminder.title(at: start - 30) == "Ada is speaking in 1 minute")
        #expect(reminder.title(at: start + 5) == "Ada is speaking now")
        #expect(reminder.body == "Shaders\nTap to join the virtual session")
    }

    @Test func planningSchedulesUpcomingAndCancelsStaleReminders() {
        let events = [event(date: "2026-10-10", speakers: [speaker(id: "s1", start: "10:00 AM"), speaker(id: "s2", start: "2:00 PM")])]
        let s1Start = Date(timeIntervalSince1970: 1_791_651_600)
        var state = MeetingReminderState(scheduledKeys: ["old"])
        let plan = MeetingReminderPlanner.plan(events: events, state: &state, now: s1Start - 3600)
        #expect(plan.scheduled.count == 2)
        let firstDelay: TimeInterval = plan.scheduled.first?.delay ?? -1
        #expect(firstDelay == 3480)
        let cancelled = plan.cancelledKeys.sorted()
        #expect(cancelled == ["old"])
        #expect(state.scheduledKeys.count == 2)

        let firstKey = plan.scheduled[0].reminder.key
        let firstMark = state.markFired(firstKey, end: s1Start + 1800)
        let secondMark = state.markFired(firstKey, end: s1Start + 1800)
        #expect(firstMark)
        #expect(!secondMark)
        let replanned = MeetingReminderPlanner.plan(events: events, state: &state, now: s1Start - 60)
        let replannedKeys = replanned.scheduled.map(\.reminder.key)
        let secondKey = plan.scheduled[1].reminder.key
        let replannedCancelled = replanned.cancelledKeys.sorted()
        #expect(replannedKeys == [secondKey])
        #expect(replannedCancelled == [firstKey])
    }

    @Test func firedKeysArePrunedAfterADay() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        var state = MeetingReminderState(fired: ["old": now - 90_000, "recent": now - 3600])
        state.pruneFired(now: now)
        let remaining = state.fired.keys.sorted()
        #expect(remaining == ["recent"])
    }

    @Test func deliveryPrefersTheBannerInTheForeground() {
        let now = Date(timeIntervalSince1970: 1_000)
        let reminder = MeetingReminder(key: "k", eventID: "e", eventName: nil, speakerID: "s", speakerName: "A", speakingTopic: "", start: now + 60, end: now + 600)
        var state = MeetingReminderState()
        let foreground = MeetingReminderDelivery.decide(reminder, state: &state, isForeground: true, now: now)
        let repeated = MeetingReminderDelivery.decide(reminder, state: &state, isForeground: false, now: now)
        var fresh = MeetingReminderState()
        let background = MeetingReminderDelivery.decide(reminder, state: &fresh, isForeground: false, now: now)
        let ended = MeetingReminderDelivery.decide(reminder, state: &fresh, isForeground: false, now: now + 600)
        #expect(foreground == .banner)
        #expect(repeated == .alreadyDelivered)
        #expect(background == .notification)
        #expect(ended == .ended)
    }
}

@Suite("Rating, catalogs, and notifications")
struct CatalogTests {
    @Test func ratingPolicyMatchesTheSchedule() {
        #expect(!RatingPolicy.shouldPromptForAppOpen(openCount: 0, hasBeenSentToStore: false))
        #expect(!RatingPolicy.shouldPromptForAppOpen(openCount: 19, hasBeenSentToStore: false))
        #expect(RatingPolicy.shouldPromptForAppOpen(openCount: 20, hasBeenSentToStore: false))
        #expect(RatingPolicy.shouldPromptForAppOpen(openCount: 40, hasBeenSentToStore: false))
        #expect(!RatingPolicy.shouldPromptForAppOpen(openCount: 40, hasBeenSentToStore: true))
        #expect(RatingPolicy.reachedLimitThisAnswer(countBefore: 29, countAfter: 30, limit: 30))
        #expect(!RatingPolicy.reachedLimitThisAnswer(countBefore: 30, countAfter: 31, limit: 30))
        #expect(RatingPolicy.shouldSendToStore(rating: 4))
        #expect(!RatingPolicy.shouldSendToStore(rating: 3))
    }

    @Test func careerListingsLoadAndFilter() throws {
        let listings = try JSONDecoder().decode([CareerListing].self, from: BundledContent.data("career_listings.json"))
        #expect(listings.count == 50)
        #expect(listings.allSatisfy { $0.applyURL != nil })
        #expect(listings.allSatisfy { CareerFilters.categories.contains($0.category) })
        #expect(listings.allSatisfy { CareerFilters.employmentTypes.contains($0.employmentType) })
        #expect(CareerFilters.filter(listings, query: "", category: "All", employmentType: "All").count == 50)

        let games = CareerFilters.filter(listings, query: "", category: "Game Development", employmentType: "All")
        #expect(!games.isEmpty && games.allSatisfy { $0.category == "Game Development" })
        let tech = try #require(listings.first?.technologies.first)
        #expect(CareerFilters.filter(listings, query: "  \(tech.uppercased()) ", category: "All", employmentType: "All").contains(listings[0]))
        #expect(CareerFilters.filter(listings, query: "zzzz-no-match", category: "All", employmentType: "All").isEmpty)
        #expect(CareerFilters.isFiltering(query: " ", category: "All", employmentType: "Contract"))
        #expect(!CareerFilters.isFiltering(query: " ", category: "All", employmentType: "All"))
    }

    @Test func resourcesLoadAndFilterByTechnology() throws {
        let resources = try JSONDecoder().decode([LearningResource].self, from: BundledContent.data("resources.json"))
        #expect(resources.count == 19)
        #expect(ResourceFilters.filter(resources, category: "All").count == 19)
        let kotlin = ResourceFilters.filter(resources, category: "kotlin")
        #expect(kotlin.allSatisfy { $0.categories.contains { $0.lowercased() == "kotlin" } })
    }

    @Test func gamesCatalogLoadsWithSectionsAndCallsToAction() throws {
        let catalog = try GameCatalog.decode(BundledContent.data("games.json"))
        #expect(catalog.games.count == 5)
        #expect(catalog.genres.first == "All")
        let pog = try #require(catalog.game(id: "game_0001"))
        #expect(pog.title == "Price of Glory")
        #expect(pog.logo == .asset("pog_logo"))
        #expect(pog.screenshots.count == 6)
        #expect(pog.callsToAction.map(\.label) == ["Download for Android", "Download for iOS", "Visit Website"])
        #expect(pog.social.discord != nil)

        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let sections = GameCatalog.sections(for: catalog.games, now: now)
        #expect(sections.featured.first?.id == "game_0001")
        #expect(catalog.filtered(query: "glory", genre: nil, gameplayType: nil).map(\.id) == ["game_0001"])
        #expect(catalog.filtered(query: "", genre: "Strategy", gameplayType: "Casual").allSatisfy { $0.gameplayType == "Casual" })

        let assetNames = catalog.games.flatMap { game in
            ([game.logo].compactMap { $0 } + game.screenshots + game.featureGraphics).compactMap { media -> String? in
                if case .asset(let name) = media { return name }
                return nil
            }
        }
        #expect(!assetNames.isEmpty)
    }

    @Test func otherStoreLabelsDependOnTheHost() {
        #expect(Game.otherStoreLabel(for: URL(string: "https://www.meta.com/x")!, comingSoon: true) == "Wishlist on Meta Quest")
        #expect(Game.otherStoreLabel(for: URL(string: "https://oculus.com/x")!, comingSoon: false) == "Get it on Meta Quest")
        #expect(Game.otherStoreLabel(for: URL(string: "https://linktr.ee/x")!, comingSoon: false) == "Visit Linktree")
        #expect(Game.otherStoreLabel(for: URL(string: "https://notmeta.com/x")!, comingSoon: false) == "View Store Page")
    }

    @Test func gamesResourcesResolveAgainstPartners() throws {
        let categories = try JSONDecoder().decode([GamesResourceCategory].self, from: BundledContent.data("games_resources.json"))
        let partners = try JSONDecoder().decode([PartnerDTO].self, from: BundledContent.data("partners.json")).map(Partner.init(dto:))
        let sections = GamesResourcesResolver.resolve(categories, partners: partners)
        #expect(sections.count == categories.count)
        #expect(sections.allSatisfy { !$0.partners.isEmpty })
        #expect(GamesResourcesResolver.resolve([GamesResourceCategory(category: "X", partnerIDs: ["missing"])], partners: partners).isEmpty)
    }

    @Test func notificationsAreAddedOncePerDayAndExpireWhenRead() async {
        let repository = LocalRepository(fileURL: nil)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let events = (1...4).map { index in
            Event(id: "e\(index)", name: "Event \(index)", host: "", start: nil, durationHours: 0, location: "", featuredImage: .none, registrationURL: nil, speakers: [])
        }

        let first = await repository.refreshNotifications(events: events, hasChallengeQuestions: true, now: now, calendar: calendar)
        #expect(first.count == 7)
        #expect(first.filter { $0.type == .event }.count == 3)
        #expect(first.contains { $0.id == "coding_challenge:daily:2027-01-15" })

        let again = await repository.refreshNotifications(events: events, hasChallengeQuestions: true, now: now + 60, calendar: calendar)
        #expect(again.count == 7)

        await repository.markNotificationRead(id: "event:e1", at: now)
        let later = now + 15 * 24 * 60 * 60
        let afterRetention = await repository.refreshNotifications(events: [], hasChallengeQuestions: false, now: later, calendar: calendar)
        #expect(!afterRetention.contains { $0.id == "event:e1" })
        #expect(afterRetention.contains { $0.id == "event:e2" })
    }
}

@Suite("Discord")
struct DiscordTests {
    @Test func parsesInviteDetails() throws {
        let json = #"{"approximate_member_count": 1200, "approximate_presence_count": 0, "guild": {"id": "42", "name": "MIKROS Mafia", "icon": "abc", "banner": null, "description": "Hi", "vanity_url_code": null, "premium_tier": 2, "premium_subscription_count": 7}}"#
        let info = try DiscordClient.parse(Data(json.utf8))
        #expect(info.memberCount == 1200)
        #expect(info.onlineCount == nil)
        #expect(info.serverName == "MIKROS Mafia")
        #expect(info.bannerURL == nil)
        #expect(info.iconURL?.absoluteString == "https://cdn.discordapp.com/icons/42/abc.png")
        #expect(info.inviteCode() == AppLinks.discordInviteCode)
        #expect(info.boostLevel == 2)
        #expect(info.boostCount == 7)
        #expect(info.initial == "M")
    }

    @Test func httpFailuresAreReportedToAnalytics() async {
        let transport = FakeTransport { _ in HTTPResponse(statusCode: 503) }
        let recorder = RecordingAnalyticsClient()
        let client = DiscordClient(transport: transport, analytics: AnalyticsService(clients: [recorder]))
        do {
            _ = try await client.serverInfo()
            Issue.record("expected a failure")
        } catch {
            #expect(error == .http(statusCode: 503))
        }
        let events = recorder.events
        #expect(events.count == 1)
        #expect(events.first?.name == "api_error")
        #expect(events.first?.parameters["status_code"] == .integer(503))
        #expect(events.first?.parameters["error_type"] == .string("http"))
    }
}
