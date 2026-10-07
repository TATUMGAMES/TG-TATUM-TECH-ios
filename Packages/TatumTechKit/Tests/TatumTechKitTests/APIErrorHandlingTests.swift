import Foundation
import Testing
@testable import TatumTechKit

@Suite("API error classification")
struct APIErrorClassifierTests {
    private func kind(_ error: any Error) -> APIErrorKind { APIErrorClassifier.classify(error).kind }
    private func http(_ status: Int, _ messages: String...) -> APIError { .http(statusCode: status, messages: messages) }

    @Test func statusesMapToTheirCategories() {
        #expect(kind(http(400)) == .badRequest)
        #expect(kind(http(401)) == .unauthorized)
        #expect(kind(http(403)) == .forbidden)
        #expect(kind(http(404)) == .notFound)
        #expect(kind(http(409)) == .conflict)
        #expect(kind(http(429)) == .rateLimited)
        #expect(kind(http(422)) == .badRequest)
        #expect(kind(http(408)) == .timeout)
        for status in [500, 502, 503, 504] { #expect(kind(http(status)) == .serverError) }
    }

    @Test func transportAndDecodingFailures() {
        #expect(kind(APIError.network("offline")) == .networkUnavailable)
        #expect(kind(APIError.timeout("timed out")) == .timeout)
        #expect(kind(TimeoutError()) == .timeout)
        #expect(kind(APIError.decoding("bad json")) == .invalidResponse)
        #expect(kind(APIError.unexpected("no url")) == .unknown)
        #expect(kind(CocoaError(.fileNoSuchFile)) == .unknown)
    }

    @Test func knownServerCodesOverrideTheStatus() {
        let exists = APIErrorClassifier.classify(http(400, "USER_ALREADY_EXISTS"))
        #expect(exists.kind == .conflict)
        #expect(exists.knownServerCode == .userAlreadyExists)
        #expect(exists.userMessage == nil)
        #expect(kind(http(406, "PASSWORDS_DO_NOT_MATCH")) == .badRequest)
        #expect(kind(http(414, "WRONG_EMAIL_OR_PASSWORD")) == .unauthorized)
        #expect(kind(http(419, "REFRESH_TOKEN_DOES_NOT_EXIST")) == .unauthorized)
    }

    @Test func unknownServerCodesFallBackToTheStatus() {
        let classified = APIErrorClassifier.classify(http(418, "SOMETHING_NEW"))
        #expect(classified.kind == .badRequest)
        #expect(classified.serverCode == "SOMETHING_NEW")
        #expect(classified.knownServerCode == nil)
    }

    @Test func onlySafeServerSentencesBecomeUserMessages() {
        #expect(APIErrorClassifier.classify(http(400, "  Please choose a different email.  ")).userMessage == "Please choose a different email.")
        let technical = [
            "java.lang.NullPointerException at com.example.Foo.bar(Foo.kt:12)",
            "SQLSTATE[23000]: Integrity constraint violation",
            "<html><body>Error</body></html>",
            "See https://internal.example.com/logs for details",
            "Connection refused to 10.0.0.12 on port 5432",
            "Undefined index: password in line 42",
            String(repeating: "a", count: SafeServerMessage.maxLength + 1) + " b",
        ]
        for message in technical {
            #expect(APIErrorClassifier.classify(http(500, message)).userMessage == nil, "\(message)")
        }
    }

    @Test func onlyTransientCategoriesAllowRetry() {
        let transient: Set<APIErrorKind> = [.networkUnavailable, .timeout, .rateLimited, .serverError]
        for kind in APIErrorKind.allCases { #expect(kind.isTransient == transient.contains(kind), "\(kind)") }
    }

    @Test func machineCodes() {
        #expect(APIErrorClassifier.isMachineCode("USER_ALREADY_EXISTS"))
        #expect(APIErrorClassifier.isMachineCode("UNAUTHORIZED"))
        #expect(!APIErrorClassifier.isMachineCode("User already exists"))
        #expect(!APIErrorClassifier.isMachineCode("OK"))
    }
}

@Suite("API error presentation")
struct APIErrorPresentationTests {
    private func signUp(_ error: any Error) -> APIErrorPresentation { APIErrorPresentation(error: error, operation: .signUp) }
    private func http(_ status: Int, _ messages: String...) -> APIError { .http(statusCode: status, messages: messages) }

    @Test func existingAccountUsesTheSignUpTitleAndOwnCopy() {
        let presentation = signUp(http(400, "USER_ALREADY_EXISTS"))
        #expect(presentation.usesOperationTitle)
        #expect(presentation.message == .accountExists)
        #expect(presentation.serverMessage == nil)
        #expect(!presentation.canRetry)
    }

    @Test func validationCodesUseTheAppsCopy() {
        #expect(signUp(http(405, "INVALID_EMAIL_FORMAT")).message == .invalidEmail)
        #expect(signUp(http(406, "INVALID_PASSWORD_FORMAT")).message == .invalidPassword)
        #expect(signUp(http(406, "PASSWORDS_DO_NOT_MATCH")).message == .passwordsDoNotMatch)
        #expect(APIErrorPresentation(error: http(414, "WRONG_EMAIL_OR_PASSWORD"), operation: .signIn).message == .wrongEmailOrPassword)
    }

    @Test func eachCategoryHasItsOwnMessage() {
        #expect(signUp(http(400)).message == .badRequest)
        #expect(signUp(http(401)).message == .credentialsRejected)
        #expect(APIErrorPresentation(error: http(401), operation: .loadContent).message == .sessionExpired)
        #expect(signUp(http(403)).message == .forbidden)
        #expect(signUp(http(404)).message == .service)
        #expect(signUp(http(409)).message == .conflict)
        #expect(signUp(http(429)).message == .rateLimited)
        #expect(signUp(http(503)).message == .server)
        #expect(signUp(APIError.network("offline")).message == .network)
        #expect(signUp(APIError.timeout("timed out")).message == .timeout)
        #expect(signUp(APIError.decoding("bad")).message == .service)
        #expect(signUp(APIError.unexpected("boom")).message == .service)
    }

    @Test func serviceAndConnectivityFailuresUseTheGenericTitle() {
        for error in [http(404), http(500), APIError.network("offline"), APIError.decoding("bad")] {
            #expect(!signUp(error).usesOperationTitle, "\(error)")
        }
        for status in [400, 401, 403, 409] {
            #expect(signUp(http(status)).usesOperationTitle, "\(status)")
        }
    }

    @Test func onlyTransientFailuresOfferTryAgain() {
        #expect(signUp(APIError.network("offline")).canRetry)
        #expect(signUp(APIError.timeout("timed out")).canRetry)
        #expect(signUp(http(429)).canRetry)
        #expect(signUp(http(500)).canRetry)
        for status in [400, 401, 403, 404, 409] { #expect(!signUp(http(status)).canRetry, "\(status)") }
    }

    @Test func rawExceptionsAndTechnicalTextNeverReachTheUI() {
        let technical: [any Error] = [
            http(500, "java.lang.NullPointerException at com.example.Foo.bar(Foo.kt:12)"),
            http(500, "<h1>A PHP Error was encountered</h1>"),
            APIError.decoding("keyNotFound(CodingKeys(stringValue: \"data\"))"),
            APIError.unexpected("Invalid URL for path x"),
            APIError.network("Error Domain=NSURLErrorDomain Code=-1004 \"Could not connect to the server.\""),
        ]
        for error in technical { #expect(signUp(error).serverMessage == nil, "\(error)") }
    }

    @Test func safeServerSentencesArePassedThrough() {
        #expect(signUp(http(400, "Sign ups are paused for maintenance.")).serverMessage == "Sign ups are paused for maintenance.")
    }
}

@Suite("API failure log")
struct APIErrorLogTests {
    private let signUpURL = URL(string: "https://tg-api-new-stage.uc.r.appspot.com/tatum-tech/signup?debug=1")!

    @Test func envelopeErrorListsBothStatusesCodeAndEnvironment() {
        let failure = APIRequestFailure(
            method: .post, url: signUpURL, durationMilliseconds: 42,
            error: .http(statusCode: 406, messages: ["PASSWORDS_DO_NOT_MATCH"]),
            responseStatusCode: 200,
            responseBody: Data(#"{"status":{"statusCode":406,"statusMessage":"PASSWORDS_DO_NOT_MATCH"},"data":{}}"#.utf8)
        )
        let log = APIErrorLog.describe(failure)

        #expect(log.contains("Environment: stage"))
        #expect(log.contains("Method: POST"))
        #expect(log.contains("Endpoint: /tatum-tech/signup"))
        #expect(!log.contains("debug=1"))
        #expect(log.contains("HTTP Status: 200"))
        #expect(log.contains("API Status: 406"))
        #expect(log.contains("Server Code: PASSWORDS_DO_NOT_MATCH"))
        #expect(log.contains("Error Type: badRequest"))
        #expect(log.contains("Request ID: not provided by the server"))
    }

    @Test func credentialsInResponseBodiesAreMasked() {
        let body = #"{"data":{"email":"a@b.test","password":"hunter22","confirmPassword":"hunter22","accessToken":"eyJaccess","refreshToken":"eyJrefresh","googleIdToken":"google-id","nested":[{"clientSecret":"s3cr3t"}]}}"#
        let failure = APIRequestFailure(
            method: .post, url: signUpURL, durationMilliseconds: 1,
            error: .decoding("missing field"), responseStatusCode: 201, responseBody: Data(body.utf8)
        )
        let log = APIErrorLog.describe(failure)

        for secret in ["hunter22", "eyJaccess", "eyJrefresh", "google-id", "s3cr3t"] {
            #expect(!log.contains(secret), "leaked \(secret)")
        }
        #expect(log.contains(HTTPRedaction.mask))
        #expect(log.contains("a@b.test"))
    }

    @Test func malformedJSONIsNeverWrittenOut() {
        let summary = APIErrorLog.summarizeBody(Data(#"{"password":"hunter22""#.utf8))
        #expect(!summary.contains("hunter22"))
    }

    @Test func htmlPagesAreSummarized() {
        let html = "<html><head><title>404 Page Not Found</title></head><body>\(String(repeating: "x", count: 5_000))</body></html>"
        let summary = APIErrorLog.summarizeBody(Data(html.utf8))
        #expect(summary.hasPrefix("HTML page \"404 Page Not Found\""))
        #expect(summary.count < 100)
    }

    @Test func longBodiesAreTruncated() {
        let summary = APIErrorLog.summarizeBody(Data(String(repeating: "e", count: APIErrorLog.maxBodyCharacters * 3).utf8))
        #expect(summary.count < APIErrorLog.maxBodyCharacters + 40)
    }

    @Test func transportFailuresHaveNoStatus() {
        let failure = APIRequestFailure(method: .get, url: signUpURL, durationMilliseconds: 30_000, error: .timeout("timed out"))
        let log = APIErrorLog.describe(failure)
        #expect(log.contains("HTTP Status: none (no response)"))
        #expect(log.contains("Error Type: timeout"))
        #expect(log.contains("Exception: timed out"))
    }

    @Test func productionAndCustomHostsAreLabelled() {
        #expect(APIErrorLog.environmentLabel(for: URL(string: "https://tg-api-new.uc.r.appspot.com/x")!) == "production")
        #expect(APIErrorLog.environmentLabel(for: Fixtures.baseURL) == "custom (api.example.com)")
    }
}

/// Collects failures reported by the client.
private final class RecordingFailureObserver: APIFailureObserver, @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [APIRequestFailure] = []
    var failures: [APIRequestFailure] { lock.withLock { recorded } }
    func requestFailed(_ failure: APIRequestFailure) { lock.withLock { recorded.append(failure) } }
}

@Suite("Response envelope")
struct ResponseEnvelopeTests {
    @Test func signUpSendsExactlyThePostmanFields() async throws {
        let transport = FakeTransport(json: Fixtures.authEnvelope())
        _ = try await Fixtures.client(transport).signUp(email: "a@b.co", password: "Secret1!", confirmPassword: "Secret2!", deviceID: "device-1")

        let request = try #require(transport.requests.first)
        #expect(request.method == .post)
        #expect(request.headers["Content-Type"] == "application/json; charset=utf-8")
        let body = Fixtures.json(request)
        #expect(body["email"] as? String == "a@b.co")
        #expect(body["password"] as? String == "Secret1!")
        #expect(body["confirmPassword"] as? String == "Secret2!")
        #expect(body["deviceId"] as? String == "device-1")
        #expect(body.count == 4)
    }

    @Test func errorInsideAnHTTP200BecomesAnHTTPError() async {
        let observer = RecordingFailureObserver()
        let transport = FakeTransport(json: #"{"status":{"statusCode":400,"statusMessage":"USER_ALREADY_EXISTS"},"data":{}}"#)
        let client = TatumTechAPIClient(baseURL: Fixtures.baseURL, transport: transport, failureObserver: observer)

        await #expect(throws: APIError.http(statusCode: 400, messages: ["USER_ALREADY_EXISTS"])) {
            _ = try await client.signUp(email: "a@b.co", password: "Secret1!", confirmPassword: "Secret1!", deviceID: "d")
        }
        let failure = try? #require(observer.failures.single)
        #expect(failure?.responseStatusCode == 200)
        #expect(failure?.error.statusCode == 400)
    }

    @Test func endpointsWithoutDataHonorTheEnvelope() async {
        let transport = FakeTransport(json: #"{"status":{"statusCode":401,"statusMessage":"UNAUTHORIZED"},"data":{}}"#)
        let client = Fixtures.client(transport)
        let expected = APIError.http(statusCode: 401, messages: ["UNAUTHORIZED"])
        await #expect(throws: expected) { try await client.forgotPassword(email: "a@b.co") }
        await #expect(throws: expected) { try await client.resetPassword(verifyToken: "v", password: "p") }
        await #expect(throws: expected) { try await client.signOut(accessToken: "t") }
        await #expect(throws: expected) { try await client.updateUserProfile(firstName: "Ada", lastName: nil, accessToken: "t") }
    }

    @Test func successStatusesAndMissingStatusPassThrough() async throws {
        let created = #"{"status":{"statusCode":201,"statusMessage":"CREATE_SUCCESS"},"data":{"accessToken":"a"}}"#
        let session = try await Fixtures.client(FakeTransport(json: created))
            .signUp(email: "a@b.co", password: "Secret1!", confirmPassword: "Secret1!", deviceID: "d")
        #expect(session.accessToken == "a")
        try await Fixtures.client(FakeTransport(json: "{}")).forgotPassword(email: "a@b.co")
    }

    @Test func htmlNotFoundPageFromAMissingDeploymentIsAnHTTP404() async {
        let html = "<html><head><title>404 Page Not Found</title></head><body>Not found</body></html>"
        let transport = FakeTransport(statusCode: 404, json: html)
        do {
            _ = try await Fixtures.client(transport).signUp(email: "a@b.co", password: "Secret1!", confirmPassword: "Secret1!", deviceID: "d")
            Issue.record("Expected an error")
        } catch let error as APIError {
            #expect(error.statusCode == 404)
            #expect(APIErrorPresentation(error: error, operation: .signUp).message == .service)
        } catch {
            Issue.record("Unexpected error \(error)")
        }
    }

    @Test func timeoutsAreReportedAsTimeouts() async {
        let transport = FakeTransport { _ in throw URLError(.timedOut) }
        do {
            _ = try await Fixtures.client(transport).upcomingEvents()
            Issue.record("Expected an error")
        } catch let error as APIError {
            guard case .timeout = error else { Issue.record("Expected timeout, got \(error)"); return }
            #expect(error.isNetworkFailure)
        } catch {
            Issue.record("Unexpected error \(error)")
        }
    }
}

@Suite("Session rejection inside the envelope")
struct SessionEnvelopeTests {
    private let storage = InMemorySecureStore()
    private var store: SecureValue<TatumTechSession> { SecureValue(store: storage, key: "session") }

    private func signedInManager(_ transport: FakeTransport, expiresIn: TimeInterval) throws -> SessionManager {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        try store.save(TatumTechSession(
            accessToken: "access-1", refreshToken: "refresh-1",
            expiresAt: now.addingTimeInterval(expiresIn), authMethod: .email
        ))
        return SessionManager(
            client: Fixtures.client(transport), store: store,
            deviceIdentifier: FixedDeviceIdentifier("device-1"), now: { now }
        )
    }

    @Test func refreshRejectedWith419SignsOut() async throws {
        let transport = FakeTransport(json: #"{"status":{"statusCode":419,"statusMessage":"REFRESH_TOKEN_DOES_NOT_EXIST"},"data":{}}"#)
        let manager = try signedInManager(transport, expiresIn: 60)

        #expect(await manager.refreshIfNeeded() == .signedOut)
        #expect(await manager.isSignedIn == false)
        #expect(store.load() == nil)
    }

    @Test func authenticatedCallRetriesAfterA401InsideTheEnvelope() async throws {
        let transport = FakeTransport { request in
            if request.url.path == "/tatum-tech/refreshToken" {
                return HTTPResponse(statusCode: 200, body: Data(Fixtures.authEnvelope(access: "access-2").utf8))
            }
            let fresh = request.headers["Authorization"] == "Bearer access-2"
            let status = fresh ? #"{"status":{"statusCode":200},"data":{}}"# : #"{"status":{"statusCode":401,"statusMessage":"UNAUTHORIZED"},"data":{}}"#
            return HTTPResponse(statusCode: 200, body: Data(status.utf8))
        }
        let manager = try signedInManager(transport, expiresIn: 86_400)

        try await manager.authenticated { client, token in
            try await client.updateUserProfile(firstName: "Ada", lastName: nil, accessToken: token)
        }
        #expect(transport.requests.filter { $0.url.path == "/tatum-tech/updateUserProfile" }.count == 2)
    }
}

@Suite("Environment selection")
struct EnvironmentSelectionTests {
    private func resolve(_ environment: String?, debug: Bool) -> AppConfiguration {
        var info: [String: Any] = [:]
        if let environment { info[AppConfiguration.InfoKey.environment] = environment }
        return AppConfiguration.resolve(infoDictionary: info, isDebugBuild: debug)
    }

    @Test func debugBuildsDefaultToStage() {
        for value in [nil, "", "  ", "bogus", "$(TATUM_TECH_ENVIRONMENT)"] {
            let configuration = resolve(value, debug: true)
            #expect(configuration.environment == .stage, "\(String(describing: value))")
            #expect(configuration.environmentSource == .debugDefault)
            #expect(configuration.environment.baseURL.absoluteString == "https://tg-api-new-stage.uc.r.appspot.com")
        }
    }

    @Test func debugBuildsCanOptIntoEitherEnvironment() {
        #expect(resolve("production", debug: true).environment == .production)
        #expect(resolve(" STAGE ", debug: true).environment == .stage)
        #expect(resolve("production", debug: true).environmentSource == .buildSetting)
    }

    @Test func releaseBuildsAlwaysUseProduction() {
        for value in [nil, "", "stage", "production"] {
            let configuration = resolve(value, debug: false)
            #expect(configuration.environment == .production)
            #expect(configuration.environmentSource == .releaseBuild)
            #expect(configuration.environment.baseURL.absoluteString == "https://tg-api-new.uc.r.appspot.com")
            #expect(!configuration.logsHTTPTraffic)
        }
    }

    @Test func environmentNamesAreParsedLeniently() {
        #expect(APIEnvironment(settingValue: " Stage ") == .stage)
        #expect(APIEnvironment(settingValue: "bogus") == nil)
        #expect(APIEnvironment(settingValue: nil) == nil)
    }

    @Test func launchLogNamesTheEnvironmentAndWhy() {
        let description = resolve(nil, debug: true).environmentDescription
        #expect(description == "Tatum Tech API: stage https://tg-api-new-stage.uc.r.appspot.com (debug build default), data source network")
    }
}

private extension Array {
    var single: Element? { count == 1 ? first : nil }
}
