import Foundation
import Testing
@testable import TatumTechKit

@Suite("Content models and repository")
struct ContentTests {

    @Test(arguments: [
        ("https://cdn.example.com/a.png", ImageSource.remote(URL(string: "https://cdn.example.com/a.png")!)),
        ("drawable:speaker_jeff", .bundled(name: "speaker_jeff")),
        ("partner_logo_ucla", .bundled(name: "partner_logo_ucla")),
        ("color://spring_purple", .swatch(name: "spring_purple")),
        ("  ", .none),
        ("drawable:", .none)
    ])
    func imageSources(value: String, expected: ImageSource) {
        #expect(ImageSource(contentValue: value) == expected)
    }

    @Test func eventStartKeepsThePublishedOffset() throws {
        let utc = try #require(EventStart(iso8601: "2026-10-10T11:30:00Z"))
        #expect(utc.timeZone.secondsFromGMT() == 0)
        #expect(utc.date == Date(timeIntervalSince1970: 1_791_631_800))

        let pacific = try #require(EventStart(iso8601: "2026-10-10T11:30:00-07:00"))
        #expect(pacific.timeZone.secondsFromGMT() == -7 * 3600)
        #expect(pacific.date.timeIntervalSince(utc.date) == 7 * 3600)

        #expect(EventStart(iso8601: "2026-10-10T11:30:00.250Z") != nil)
        #expect(EventStart(iso8601: "October 10") == nil)
    }

    @Test func speakersSortBySortOrderThenStartTime() {
        let speakers = [
            Speaker(id: "c", name: "C", topic: "", startTime: "4:00 PM", sortOrder: 2),
            Speaker(id: "b", name: "B", topic: "", startTime: "3:30 PM", sortOrder: 2),
            Speaker(id: "a", name: "A", topic: "", sortOrder: 1)
        ]
        #expect(speakers.inSpeakingOrder().map(\.id) == ["a", "b", "c"])
    }

    @Test func partnerCategoriesAcceptApiAndBundledLabels() {
        #expect(PartnerCategory(contentValue: "Game Studios") == .gameStudios)
        #expect(PartnerCategory(contentValue: "game studio partners") == .gameStudios)
        #expect(PartnerCategory(contentValue: "Sponsors") == .other("Sponsors"))
        #expect(PartnerCategory.gameStudios.shortName == "Game Studios")
        #expect(PartnerCategory.gameStudios.fullName == "Game Studio Partners")
    }

    @Test func partnerDirectoryPutsFeaturedFirstThenSortsByName() {
        let partners = [
            Partner(id: "1", name: "zeta", category: .community),
            Partner(id: "2", name: "Alpha", category: .corporate),
            Partner(id: "3", name: "Mid", category: .community, isFeatured: true),
            Partner(id: "4", name: "beta", category: .community)
        ]
        #expect(PartnerDirectory.filter(partners, category: nil).map(\.id) == ["3", "2", "4", "1"])
        #expect(PartnerDirectory.filter(partners, category: .community).map(\.id) == ["3", "4", "1"])
        #expect(PartnerDirectory.filter(partners, category: .technology).isEmpty)
    }

    @Test func repositoryMapsAndSortsEvents() async throws {
        let json = Fixtures.envelope(#"""
        {"events":[
          {"id":"late","name":"Spring","date":"2027-03-01T10:00:00Z","lumaUrl":" "},
          {"id":"undated","name":"TBD"},
          {"id":"soon","name":"Fall","host":"Tatum Games","date":"2026-10-10T11:30:00Z","durationHours":5,
           "featuredImage":"tatum_tech_flyer_01","lumaUrl":"https://luma.com/x",
           "virtualSpeakers":[{"id":"b","name":"B","sortOrder":2,"meetUrl":"https://meet.google.com/b"},{"id":"a","name":"A","sortOrder":1}]}
        ]}
        """#)
        let repository = APIContentRepository(client: Fixtures.client(FakeTransport(json: json)))
        let events = try await repository.upcomingEvents()

        #expect(events.map(\.id) == ["soon", "late", "undated"])
        let fall = events[0]
        #expect(fall.canRegister)
        #expect(fall.featuredImage == .bundled(name: "tatum_tech_flyer_01"))
        #expect(fall.speakers.map(\.id) == ["a", "b"])
        #expect(fall.speakers[1].canJoin)
        #expect(!fall.speakers[0].canJoin)
        #expect(!events[1].canRegister)
    }

    @Test func repositoryMapsPartners() async throws {
        let json = Fixtures.envelope(#"""
        {"partners":[{"id":"p","name":"Studio","category":"Game Studios","featured":true,
          "contacts":[{"name":"A","email":"a@x.co"},{"name":"B","phone":"+1 555"}],
          "additionalLinks":[{"label":"Press","url":"https://x.co/press"},{"label":"Broken","url":""}],
          "socialLinks":{"x":"https://x.com/s","youtube":" "}}]}
        """#)
        let repository = APIContentRepository(client: Fixtures.client(FakeTransport(json: json)))
        let partner = try #require(try await repository.partners().first)

        #expect(partner.category == .gameStudios)
        #expect(partner.isFeatured)
        #expect(partner.emailContacts.map(\.name) == ["A"])
        #expect(partner.phoneNumber == "+1 555")
        #expect(partner.additionalLinks.map(\.label) == ["Press"])
        #expect(partner.socialLinks == [SocialLink(platform: .x, url: URL(string: "https://x.com/s")!)])
        #expect(partner.logo == .none)
    }
}
