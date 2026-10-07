import Foundation
import Testing
@testable import TatumTechKit

@Suite("Error parsing, redaction, timeout")
struct NetworkingSupportTests {

    @Test(arguments: [
        (#"{"errors":[{"message":"Email taken"},"Second"]}"#, ["Email taken", "Second"]),
        (#"{"error":{"message":"Bad token"}}"#, ["Bad token"]),
        (#"{"error":"Nope"}"#, ["Nope"]),
        (#"{"message":"  Trimmed  "}"#, ["Trimmed"]),
        (#"{"status":{"statusCode":400,"statusMessage":"Invalid"}}"#, ["Invalid"]),
        (#"{"message":"   "}"#, []),
        ("not json", []),
        ("", [])
    ])
    func errorMessages(body: String, expected: [String]) {
        #expect(ErrorMessageParser.messages(from: Data(body.utf8)) == expected)
    }

    @Test func serverMessageSkipsBlankEntries() {
        #expect(APIError.http(statusCode: 400, messages: ["  ", " Real "]).serverMessage == "Real")
        #expect(APIError.network("offline").serverMessage == nil)
    }

    @Test func redactsSensitiveHeadersAndBodyFields() throws {
        let headers = HTTPRedaction.redactedHeaders(["Authorization": "Bearer x", "x-api-key": "k", "Accept": "application/json"])
        #expect(headers["Authorization"] == HTTPRedaction.mask)
        #expect(headers["x-api-key"] == HTTPRedaction.mask)
        #expect(headers["Accept"] == "application/json")

        let body = Data(#"{"email":"a@b.co","password":"Secret!","data":{"accessToken":"t","refreshToken":"r"}}"#.utf8)
        let text = try #require(HTTPRedaction.redactedBody(body))
        #expect(text.contains("a@b.co"))
        #expect(!text.contains("Secret!"))
        #expect(!text.contains("\"t\""))
        #expect(!text.contains("\"r\""))
    }

    @Test func timeoutThrowsWhenOperationIsSlow() async {
        await #expect(throws: TimeoutError.self) {
            try await withTimeout(.milliseconds(50)) {
                try await Task.sleep(for: .seconds(5))
                return 1
            }
        }
    }

    @Test func timeoutReturnsFastResults() async throws {
        let value = try await withTimeout(.seconds(5)) { 7 }
        #expect(value == 7)
    }
}

@Suite("AppConfiguration")
struct AppConfigurationTests {

    @Test func debugBuildsHonourSettings() {
        let configuration = AppConfiguration.resolve(
            infoDictionary: ["TatumTechEnvironment": "STAGE", "TatumTechDataSource": "LOCAL_JSON", "TatumTechAPIKey": " key "],
            isDebugBuild: true
        )
        #expect(configuration.environment == .stage)
        #expect(configuration.dataSource == .localJSON)
        #expect(configuration.apiKey == "key")
        #expect(configuration.logsHTTPTraffic)
    }

    @Test func releaseBuildsAlwaysUseProductionNetwork() {
        let configuration = AppConfiguration.resolve(
            infoDictionary: ["TatumTechEnvironment": "stage", "TatumTechDataSource": "localJSON"],
            isDebugBuild: false
        )
        #expect(configuration == AppConfiguration(
            environment: .production, environmentSource: .releaseBuild, dataSource: .network, apiKey: nil, logsHTTPTraffic: false
        ))
    }

    @Test func blankOrUnexpandedValuesFallBack() {
        let configuration = AppConfiguration.resolve(
            infoDictionary: ["TatumTechEnvironment": "", "TatumTechAPIKey": "$(TATUM_TECH_API_KEY)"],
            isDebugBuild: true
        )
        #expect(configuration.environment == .stage)
        #expect(configuration.dataSource == .network)
        #expect(configuration.apiKey == nil)
    }

    @Test func environmentsPointAtTheTatumTechHosts() {
        #expect(APIEnvironment.production.baseURL.absoluteString == "https://tg-api-new.uc.r.appspot.com")
        #expect(APIEnvironment.stage.baseURL.absoluteString == "https://tg-api-new-stage.uc.r.appspot.com")
    }
}
