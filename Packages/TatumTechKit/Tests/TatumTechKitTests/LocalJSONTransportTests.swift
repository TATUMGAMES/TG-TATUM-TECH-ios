import Foundation
import Testing
@testable import TatumTechKit

@Suite("LocalJSONTransport")
struct LocalJSONTransportTests {

    private static let events = #"""
    [{"id":1,"name":"Fall","virtualSpeakers":[{"id":"s1","name":"Jeff"}]}]
    """#
    private static let partners = #"""
    [{"id":"p1","name":"One","category":"Game Studio Partners"},{"id":"p2","name":"Two","category":"Community Partners"}]
    """#

    private func client() -> TatumTechAPIClient {
        let transport = LocalJSONTransport { file in
            switch file {
            case LocalJSONTransport.eventsFile: Data(Self.events.utf8)
            case LocalJSONTransport.partnersFile: Data(Self.partners.utf8)
            default: throw CocoaError(.fileNoSuchFile)
            }
        }
        return TatumTechAPIClient(baseURL: APIEnvironment.production.baseURL, transport: transport)
    }

    @Test func servesEventsSpeakersAndDetails() async throws {
        let client = client()
        #expect(try await client.upcomingEvents().map(\.id) == ["1"])
        #expect(try await client.event(id: "1").name == "Fall")
        #expect(try await client.eventSpeakers(eventID: "1").map(\.id) == ["s1"])
    }

    @Test func mapsBundledPartnerCategoriesToApiValues() async throws {
        let client = client()
        let partners = try await client.partners()
        #expect(partners.map(\.category) == ["Game Studios", "Community"])
        #expect(try await client.partners(category: .gameStudios).map(\.id) == ["p1"])
        #expect(try await client.partner(id: "p2").name == "Two")
    }

    @Test func unknownIdsAre404() async {
        await #expect(throws: APIError.self) { _ = try await client().event(id: "missing") }
        do {
            _ = try await client().partner(id: "missing")
        } catch let error as APIError {
            #expect(error.statusCode == 404)
        } catch {
            Issue.record("Unexpected \(error)")
        }
    }

    @Test func authEndpointsAreNotImplemented() async {
        do {
            _ = try await client().signIn(email: "a@b.co", password: "Secret!", deviceID: "d")
            Issue.record("Expected an error")
        } catch let error as APIError {
            #expect(error.statusCode == 501)
            #expect(error.serverMessage?.contains("no local JSON data") == true)
        } catch {
            Issue.record("Unexpected \(error)")
        }
    }

    @Test func routeIgnoresHostAndApiRoot() {
        #expect(LocalJSONTransport.route(of: URL(string: "https://h/tatum-tech/events/1/speakers")!) == ["events", "1", "speakers"])
        #expect(LocalJSONTransport.route(of: URL(string: "https://h/other/path")!) == ["other", "path"])
    }

    /// The JSON shipped with the app must decode through the real client in local mode.
    @Test func bundledAppContentDecodes() async throws {
        let transport = LocalJSONTransport { try Fixtures.appContent($0) }
        let repository = APIContentRepository(
            client: TatumTechAPIClient(baseURL: APIEnvironment.production.baseURL, transport: transport)
        )
        let events = try await repository.upcomingEvents()
        #expect(!events.isEmpty)
        #expect(events.allSatisfy { !$0.name.isEmpty })

        let partners = try await repository.partners()
        #expect(!partners.isEmpty)
        #expect(Set(partners.map(\.id)).count == partners.count)
        for partner in partners {
            #expect(PartnerCategory.filterable.contains(partner.category), "\(partner.id) has category \(partner.category)")
        }
    }
}
