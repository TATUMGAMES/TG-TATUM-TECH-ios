import Foundation
import OSLog
import TatumTechKit

/// Writes HTTP traffic to the unified log (Xcode console, Console.app). Installed only in Debug
/// builds; credentials are masked before anything is written.
struct OSLogTrafficLogger: HTTPTrafficLogger {
    private let logger = Logger(subsystem: AppLog.subsystem, category: "HTTP")

    func log(request: HTTPRequest) {
        let headers = HTTPRedaction.redactedHeaders(request.headers)
        let body = HTTPRedaction.redactedBody(request.body) ?? "-"
        logger.debug("""
        → \(request.method.rawValue, privacy: .public) \(request.url.absoluteString, privacy: .public)
        headers: \(headers.description, privacy: .public)
        body: \(body, privacy: .public)
        """)
    }

    func log(response: HTTPResponse, for request: HTTPRequest, duration: Duration) {
        let body = HTTPRedaction.redactedBody(response.body) ?? "-"
        logger.debug("""
        ← \(response.statusCode, privacy: .public) \(request.method.rawValue, privacy: .public) \(request.url.absoluteString, privacy: .public) (\(Self.milliseconds(duration), privacy: .public) ms)
        body: \(body, privacy: .public)
        """)
    }

    func log(failure: any Error, for request: HTTPRequest, duration: Duration) {
        logger.error("""
        ✕ \(request.method.rawValue, privacy: .public) \(request.url.absoluteString, privacy: .public) (\(Self.milliseconds(duration), privacy: .public) ms): \(String(describing: failure), privacy: .public)
        """)
    }

    private static func milliseconds(_ duration: Duration) -> Int64 {
        let parts = duration.components
        return parts.seconds * 1000 + parts.attoseconds / 1_000_000_000_000_000
    }
}
