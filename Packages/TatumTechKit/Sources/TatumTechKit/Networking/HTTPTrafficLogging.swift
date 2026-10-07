import Foundation

/// Receives every request and its outcome. The app installs one only in Debug builds.
public protocol HTTPTrafficLogger: Sendable {
    func log(request: HTTPRequest)
    func log(response: HTTPResponse, for request: HTTPRequest, duration: Duration)
    func log(failure: any Error, for request: HTTPRequest, duration: Duration)
}

/// Masks credentials before traffic is written anywhere.
public enum HTTPRedaction {
    public static let mask = "████"

    static let sensitiveHeaders: Set<String> = ["authorization", "x-api-key", "cookie", "set-cookie"]
    static let sensitiveKeyFragments = ["password", "token", "secret", "authorization", "apikey", "api_key"]

    public static func redactedHeaders(_ headers: [String: String]) -> [String: String] {
        headers.reduce(into: [:]) { result, header in
            result[header.key] = sensitiveHeaders.contains(header.key.lowercased()) ? mask : header.value
        }
    }

    /// JSON with sensitive values masked, or the raw text for non-JSON bodies.
    public static func redactedBody(_ body: Data?, limit: Int = 16_384, prettyPrinted: Bool = true) -> String? {
        guard let body, !body.isEmpty else { return nil }
        let options: JSONSerialization.WritingOptions = prettyPrinted
            ? [.prettyPrinted, .sortedKeys, .fragmentsAllowed]
            : [.sortedKeys, .fragmentsAllowed]
        if let object = try? JSONSerialization.jsonObject(with: body, options: [.fragmentsAllowed]),
           let data = try? JSONSerialization.data(withJSONObject: redact(object), options: options),
           let text = String(data: data, encoding: .utf8) {
            return truncated(text, limit: limit)
        }
        return String(data: body, encoding: .utf8).map { truncated($0, limit: limit) } ?? "<\(body.count) bytes>"
    }

    private static func redact(_ value: Any) -> Any {
        if let object = value as? [String: Any] {
            return object.reduce(into: [String: Any]()) { result, entry in
                let key = entry.key.lowercased()
                let isSensitive = sensitiveKeyFragments.contains { key.contains($0) }
                result[entry.key] = isSensitive ? mask : redact(entry.value)
            }
        }
        if let array = value as? [Any] {
            return array.map(redact)
        }
        return value
    }

    private static func truncated(_ text: String, limit: Int) -> String {
        text.count > limit ? String(text.prefix(limit)) + "\n… (truncated)" : text
    }
}
