import Foundation
import Testing
@testable import TatumTechKit

@Suite("TatumTechAPIClient")
struct TatumTechAPIClientTests {

    @Test func signInPostsCredentialsAndDecodesSession() async throws {
        let transport = FakeTransport(json: Fixtures.authEnvelope())
        let session = try await Fixtures.client(transport).signIn(email: "ada@example.com", password: "Secret!", deviceID: "device-1")

        let request = try #require(transport.requests.first)
        #expect(request.method == .post)
        #expect(request.url.absoluteString == "https://api.example.com/tatum-tech/signin")
        #expect(request.headers["Content-Type"] == "application/json; charset=utf-8")
        #expect(request.headers["Accept"] == "application/json")
        #expect(request.headers["Authorization"] == nil)
        let body = Fixtures.json(request)
        #expect(body["email"] as? String == "ada@example.com")
        #expect(body["password"] as? String == "Secret!")
        #expect(body["deviceId"] as? String == "device-1")

        #expect(session.accessToken == "access-1")
        #expect(session.refreshToken == "refresh-1")
        #expect(session.expiresIn == 86_400)
        #expect(session.user?.id == "42")
    }

    @Test func googleSignInSendsIdTokenToSignInEndpoint() async throws {
        let transport = FakeTransport(json: Fixtures.authEnvelope())
        _ = try await Fixtures.client(transport).signInWithGoogle(idToken: "google-token", deviceID: "device-1")

        let request = try #require(transport.requests.first)
        #expect(request.url.path == "/tatum-tech/signin")
        let body = Fixtures.json(request)
        #expect(body["googleIdToken"] as? String == "google-token")
        #expect(body["deviceId"] as? String == "device-1")
        #expect(body["password"] == nil)
    }

    @Test func signUpSendsConfirmation() async throws {
        let transport = FakeTransport(json: Fixtures.authEnvelope())
        _ = try await Fixtures.client(transport).signUp(email: "a@b.co", password: "Secret!", confirmPassword: "Secret!", deviceID: "d")
        let request = try #require(transport.requests.first)
        #expect(request.url.path == "/tatum-tech/signup")
        #expect(Fixtures.json(request)["confirmPassword"] as? String == "Secret!")
    }

    @Test func refreshSendsPreviousAccessTokenAsBearer() async throws {
        let transport = FakeTransport(json: Fixtures.authEnvelope(access: "access-2"))
        _ = try await Fixtures.client(transport).refreshToken("refresh-1", deviceID: "d", previousAccessToken: "access-1")
        let request = try #require(transport.requests.first)
        #expect(request.url.path == "/tatum-tech/refreshToken")
        #expect(request.headers["Authorization"] == "Bearer access-1")
        #expect(Fixtures.json(request)["refreshToken"] as? String == "refresh-1")
    }

    @Test func authenticatedEndpointsCarryTheToken() async throws {
        let transport = FakeTransport(json: #"{"status":{"statusCode":200}}"#)
        let client = Fixtures.client(transport)
        try await client.signOut(accessToken: "Bearer token-1")
        try await client.updateUserProfile(firstName: "Ada", lastName: nil, accessToken: "token-1")

        let requests = transport.requests
        #expect(requests[0].url.path == "/tatum-tech/signout")
        #expect(requests[0].headers["Authorization"] == "Bearer token-1")
        #expect(requests[0].body == nil)
        #expect(requests[1].url.path == "/tatum-tech/updateUserProfile")
        let profile = Fixtures.json(requests[1])
        #expect(profile["firstName"] as? String == "Ada")
        #expect(profile.keys.contains("lastName") == false)
    }

    @Test func apiKeyIsSentWhenConfigured() async throws {
        let transport = FakeTransport(json: Fixtures.envelope(#"{"events":[]}"#))
        _ = try await Fixtures.client(transport, apiKey: "public-key").upcomingEvents()
        #expect(transport.requests.first?.headers["x-api-key"] == "public-key")
    }

    @Test func eventsDecodeNumericIdsAndDefaults() async throws {
        let json = Fixtures.envelope(#"""
        {"events":[{"id":1,"name":"Fall","date":"2026-10-10T11:30:00Z","virtualSpeakers":[{"id":"s1","name":"Jeff"}]}]}
        """#)
        let events = try await Fixtures.client(FakeTransport(json: json)).upcomingEvents()
        let event = try #require(events.first)
        #expect(event.id == "1")
        #expect(event.durationHours == nil)
        #expect(event.virtualSpeakers.first?.sortOrder == 0)
    }

    @Test func eventPathEncodesIdentifiers() async throws {
        let transport = FakeTransport(json: Fixtures.envelope(#"{"speakers":[]}"#))
        _ = try await Fixtures.client(transport).eventSpeakers(eventID: "fall 2026/a")
        #expect(transport.requests.first?.url.absoluteString == "https://api.example.com/tatum-tech/events/fall%202026%2Fa/speakers")
    }

    @Test func partnersSendCategoryQueryOnlyWhenGiven() async throws {
        let transport = FakeTransport(json: Fixtures.envelope(#"{"partners":[]}"#))
        let client = Fixtures.client(transport)
        _ = try await client.partners()
        _ = try await client.partners(category: .gameStudios)
        #expect(transport.requests[0].url.query == nil)
        #expect(transport.requests[1].url.query == "category=Game%20Studios")
    }

    @Test func missingDataIsADecodingError() async {
        let transport = FakeTransport(json: #"{"status":{"statusCode":200}}"#)
        await #expect(throws: APIError.decoding("Response is missing 'data'")) {
            _ = try await Fixtures.client(transport).upcomingEvents()
        }
    }

    @Test func missingNestedFieldIsADecodingError() async {
        let transport = FakeTransport(json: Fixtures.envelope("{}"))
        await #expect(throws: APIError.decoding("Response is missing 'event'")) {
            _ = try await Fixtures.client(transport).event(id: "1")
        }
    }

    @Test func httpErrorsCarryServerMessages() async {
        let transport = FakeTransport(statusCode: 401, json: #"{"status":{"statusCode":401,"statusMessage":"Invalid email or password"}}"#)
        do {
            _ = try await Fixtures.client(transport).signIn(email: "a@b.co", password: "x", deviceID: "d")
            Issue.record("Expected an error")
        } catch let error as APIError {
            #expect(error.statusCode == 401)
            #expect(error.serverMessage == "Invalid email or password")
        } catch {
            Issue.record("Unexpected error \(error)")
        }
    }

    @Test func transportFailuresAreNetworkErrors() async {
        let transport = FakeTransport { _ in throw URLError(.notConnectedToInternet) }
        do {
            _ = try await Fixtures.client(transport).upcomingEvents()
            Issue.record("Expected an error")
        } catch let error as APIError {
            #expect(error.isNetworkFailure)
        } catch {
            Issue.record("Unexpected error \(error)")
        }
    }

    @Test func cancelledTransportBecomesCancellationError() async {
        let transport = FakeTransport { _ in throw URLError(.cancelled) }
        await #expect(throws: CancellationError.self) {
            _ = try await Fixtures.client(transport).upcomingEvents()
        }
    }

    @Test func malformedSuccessBodyIsADecodingError() async {
        let transport = FakeTransport(json: "<html>")
        do {
            _ = try await Fixtures.client(transport).partners()
            Issue.record("Expected an error")
        } catch let error as APIError {
            guard case .decoding = error else { Issue.record("Expected decoding, got \(error)"); return }
        } catch {
            Issue.record("Unexpected error \(error)")
        }
    }

    @Test func bearerTokenNormalization() {
        #expect(BearerToken.header(for: "abc") == "Bearer abc")
        #expect(BearerToken.header(for: "bearer abc") == "Bearer abc")
        #expect(BearerToken.header(for: "  ") == nil)
        #expect(BearerToken.header(for: "Bearer ") == nil)
        #expect(BearerToken.bare("Bearer abc") == "abc")
    }
}
