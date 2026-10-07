import Foundation
import TatumTechKit
@testable import TatumTech

/// Answers every request with the same status and JSON body.
struct StubTransport: HTTPTransport {
    let statusCode: Int
    let json: String

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        HTTPResponse(statusCode: statusCode, body: Data(json.utf8))
    }
}

enum TestServices {
    static func accountService(
        transport: any HTTPTransport,
        store: any SecureStore = InMemorySecureStore(),
        firebase: any FirebaseAuthenticating = InMemoryFirebaseAuthentication()
    ) -> AccountService {
        let client = TatumTechAPIClient(baseURL: URL(string: "https://api.example.com")!, transport: transport)
        let sessions = SessionManager(
            client: client,
            store: SecureValue(store: store, key: "session"),
            deviceIdentifier: FixedDeviceIdentifier("test-device")
        )
        return AccountService(
            sessionManager: sessions,
            federatedStore: SecureValue(store: store, key: "federated"),
            firebase: firebase
        )
    }
}

/// Returns a fixed Google identity or failure without showing Google's sheet.
struct StubGoogleSignIn: GoogleSignInProviding {
    var result: Result<GoogleIdentity, GoogleSignInFailure>

    func signIn() async throws -> GoogleIdentity { try result.get() }
    func handle(_ url: URL) -> Bool { false }
    func disconnect() async {}
}

/// Re-authorizes with a fixed result instead of Apple's sheet.
struct StubAppleReauthorizer: AppleReauthorizing {
    var result: Result<AppleIdentity, AppleSignInFailure>

    func reauthorize() async throws -> AppleIdentity { try result.get() }
}

/// Collects analytics events.
final class RecordingAnalyticsClient: AnalyticsClient, @unchecked Sendable {
    private let lock = NSLock()
    private var names: [String] = []
    private var errors: Int = 0

    var events: [String] { lock.withLock { names } }
    var recordedErrorCount: Int { lock.withLock { errors } }

    func log(name: String, parameters: [String: AnalyticsValue]) {
        lock.withLock { names.append(name) }
    }

    func record(error: any Error) {
        lock.withLock { errors += 1 }
    }
}
