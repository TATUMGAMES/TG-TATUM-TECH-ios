import Foundation
import TatumTechKit

/// Answers every request with the same status and JSON body.
struct StubTransport: HTTPTransport {
    let statusCode: Int
    let json: String

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        HTTPResponse(statusCode: statusCode, body: Data(json.utf8))
    }
}

enum TestServices {
    static func accountService(transport: any HTTPTransport, store: any SecureStore = InMemorySecureStore()) -> AccountService {
        let client = TatumTechAPIClient(baseURL: URL(string: "https://api.example.com")!, transport: transport)
        let sessions = SessionManager(
            client: client,
            store: SecureValue(store: store, key: "session"),
            deviceIdentifier: FixedDeviceIdentifier("test-device")
        )
        return AccountService(sessionManager: sessions, federatedStore: SecureValue(store: store, key: "federated"))
    }
}
