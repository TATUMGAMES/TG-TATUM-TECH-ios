import Foundation

/// Formats one structured developer log entry per failed Tatum Tech API call, e.g.:
///
/// ```
/// [API ERROR]
/// Environment: stage
/// Method: POST
/// Endpoint: /tatum-tech/signup
/// HTTP Status: 200
/// API Status: 406
/// Server Code: PASSWORDS_DO_NOT_MATCH
/// Error Type: badRequest
/// ```
///
/// Only the path is included, never the query string, headers, or request body. Response bodies
/// are summarized with credential-like JSON values masked.
public enum APIErrorLog {
    public static let maxBodyCharacters = 500

    public static func describe(_ failure: APIRequestFailure) -> String {
        let classified = APIErrorClassifier.classify(failure.error)
        var lines = [
            "[API ERROR]",
            "Environment: \(environmentLabel(for: failure.url))",
            "Method: \(failure.method.rawValue)",
            "Endpoint: \(failure.url.path.isEmpty ? "/" : failure.url.path)",
        ]
        if let responseStatus = failure.responseStatusCode {
            lines.append("HTTP Status: \(responseStatus)")
            if let apiStatus = failure.error.statusCode, apiStatus != responseStatus {
                lines.append("API Status: \(apiStatus)")
            }
        } else {
            lines.append("HTTP Status: none (no response)")
        }
        if let code = classified.serverCode { lines.append("Server Code: \(code)") }
        lines.append("Error Type: \(classified.kind.rawValue)")
        switch failure.error {
        case let .network(detail), let .timeout(detail), let .decoding(detail), let .unexpected(detail):
            lines.append("Exception: \(singleLine(detail))")
        case .http:
            break
        }
        lines.append("Duration: \(failure.durationMilliseconds) ms")
        lines.append("Request ID: not provided by the server")
        if let body = failure.responseBody {
            lines.append("Response: \(summarizeBody(body))")
        }
        return lines.joined(separator: "\n")
    }

    /// The `APIEnvironment` serving `url`, or `custom (host)`.
    public static func environmentLabel(for url: URL) -> String {
        APIEnvironment.allCases.first { $0.baseURL.host == url.host }?.rawValue ?? "custom (\(url.host ?? "?"))"
    }

    /// A short, credential-free description of a response body.
    public static func summarizeBody(_ body: Data) -> String {
        guard !body.isEmpty else { return "(empty)" }
        let text = String(decoding: body, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("<") {
            let title = text.range(of: "(?is)<title>(.*?)</title>", options: .regularExpression).map {
                text[$0]
                    .replacingOccurrences(of: "(?i)</?title>", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return "HTML page\(title.map { " \"\($0)\"" } ?? "") (\(text.count) characters)"
        }
        if text.hasPrefix("{") || text.hasPrefix("[") {
            // Unparseable JSON cannot be masked, so it is never written out.
            guard (try? JSONSerialization.jsonObject(with: body, options: [.fragmentsAllowed])) != nil,
                  let redacted = HTTPRedaction.redactedBody(body, limit: .max, prettyPrinted: false)
            else { return "malformed JSON (\(text.count) characters)" }
            return truncated(redacted)
        }
        return truncated(singleLine(text))
    }

    private static func singleLine(_ text: String) -> String {
        text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    private static func truncated(_ text: String) -> String {
        text.count <= maxBodyCharacters ? text : String(text.prefix(maxBodyCharacters)) + "… (\(text.count) characters)"
    }
}
