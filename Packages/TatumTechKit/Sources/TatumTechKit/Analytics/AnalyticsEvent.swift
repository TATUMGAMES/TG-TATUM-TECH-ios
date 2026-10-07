import Foundation

/// A parameter value attached to an analytics event.
public enum AnalyticsValue: Hashable, Sendable {
    case string(String)
    case integer(Int)
}

/// Profile fields reported by `update_profile`.
public enum ProfileField: String, CaseIterable, Sendable {
    case firstName = "first_name"
    case lastName = "last_name"
    case email
}

/// What opened the rating prompt.
public enum RatingTrigger: String, Hashable, Sendable {
    case appOpen = "app_open"
    case codingChallengeComplete = "coding_challenge_complete"
}

/// How an API call failed, as reported by `api_error`.
public enum APIErrorType: String, Sendable {
    case http, timeout, connection, io, parse, unknown
}

/// One failed API call. Successful calls are never reported.
public struct APIErrorReport: Hashable, Sendable {
    /// Sanitized path (identifiers replaced), never a full URL.
    public let endpoint: String
    /// Lowercase HTTP method.
    public let method: String
    public let statusCode: Int?
    public let durationMilliseconds: Int
    public let errorType: APIErrorType

    public init(endpoint: String, method: String, statusCode: Int?, durationMilliseconds: Int, errorType: APIErrorType) {
        self.endpoint = AnalyticsSanitizer.sanitizeEndpoint(endpoint)
        self.method = method.lowercased()
        self.statusCode = statusCode
        self.durationMilliseconds = max(0, durationMilliseconds)
        self.errorType = errorType
    }
}

/// Every analytics event the app sends. Events never carry personal information.
public enum AnalyticsEvent: Hashable, Sendable {
    /// A screen was shown. `screenName` is already sanitized; see `AnalyticsSanitizer.screenName(fromRoute:)`.
    case navigate(screenName: String)
    case updateProfile(field: ProfileField)
    case scanContactCard
    case createContactCard
    case deleteAccount
    case rateApp(rating: Int, trigger: RatingTrigger, sentToStore: Bool)
    case exception(handled: Bool)
    case apiError(APIErrorReport)
    /// An existing account signed in (Firebase recommended event).
    case login(method: AuthMethod)
    /// A new account was created (Firebase recommended event).
    case signUp(method: AuthMethod)

    public var name: String {
        switch self {
        case .login: "login"
        case .signUp: "sign_up"
        case .navigate: "navigate"
        case .updateProfile: "update_profile"
        case .scanContactCard: "scan_contact_card"
        case .createContactCard: "create_contact_card"
        case .deleteAccount: "delete_account"
        case .rateApp: "rate_app"
        case .exception: "exception"
        case .apiError: "api_error"
        }
    }

    public var parameters: [String: AnalyticsValue] {
        switch self {
        case let .navigate(screenName):
            ["screen_name": .string(screenName)]
        case let .updateProfile(field):
            ["field": .string(field.rawValue)]
        case .scanContactCard, .createContactCard, .deleteAccount:
            [:]
        case let .rateApp(rating, trigger, sentToStore):
            [
                "rating": .integer(rating),
                "trigger": .string(trigger.rawValue),
                "sent_to_store": .string(sentToStore ? "true" : "false")
            ]
        case let .exception(handled):
            ["handled": .string(handled ? "true" : "false")]
        case let .apiError(report):
            report.parameters
        case let .login(method), let .signUp(method):
            ["method": .string(method.rawValue)]
        }
    }
}

extension APIErrorReport {
    var parameters: [String: AnalyticsValue] {
        var values: [String: AnalyticsValue] = [
            "endpoint": .string(endpoint),
            "method": .string(method),
            "duration_ms": .integer(durationMilliseconds),
            "error_type": .string(errorType.rawValue)
        ]
        if let statusCode { values["status_code"] = .integer(statusCode) }
        return values
    }
}

/// Turns routes and URLs into values safe to send to analytics.
public enum AnalyticsSanitizer {
    /// The route's first path segment, lowercased with `-` as `_`, e.g.
    /// `virtual_speakers_screen/{eventId}?speakerId=` → `virtual_speakers_screen`.
    public static func screenName(fromRoute route: String?) -> String {
        let raw = (route ?? "").split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
            .first.map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !raw.isEmpty else { return "unknown" }
        let base = raw.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? ""
        let trimmed = base.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "unknown" }
        return trimmed.lowercased().replacingOccurrences(of: "-", with: "_")
    }

    /// The URL's path with invite codes and identifier-like segments removed.
    public static func sanitizeEndpoint(_ url: String?) -> String {
        guard let url, !url.trimmingCharacters(in: .whitespaces).isEmpty else { return "unknown" }
        let path: String
        if let components = URLComponents(string: url), components.scheme != nil || url.hasPrefix("/") {
            path = components.path
        } else if let components = URLComponents(string: "/" + url) {
            path = components.path
        } else {
            return "unknown"
        }
        let base = path.trimmingCharacters(in: .whitespaces).isEmpty ? "/" : path
        let segments = base.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        var output: [String] = []
        var skipNext = false
        for (index, segment) in segments.enumerated() {
            if skipNext { skipNext = false; continue }
            if segment == "invites", index + 1 < segments.count, !segments[index + 1].isEmpty {
                output.append("invites")
                skipNext = true
            } else if isIdentifierLike(segment) {
                output.append("{id}")
            } else {
                output.append(segment)
            }
        }
        let joined = output.joined(separator: "/")
        return joined.isEmpty ? "/" : joined
    }

    /// Eight or more hex digits or dashes, e.g. a UUID or Mongo object id.
    private static func isIdentifierLike(_ segment: String) -> Bool {
        segment.count >= 8 && segment.allSatisfy { $0.isHexDigit || $0 == "-" }
    }
}
