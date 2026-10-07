import Foundation

/// What went wrong with an API call, independent of how the server or transport reported it.
public enum APIErrorKind: String, Sendable, Equatable, CaseIterable {
    case networkUnavailable
    case timeout
    case badRequest
    case unauthorized
    case forbidden
    case notFound
    case conflict
    case rateLimited
    case serverError
    /// A response arrived but could not be read (malformed JSON, missing fields, HTML page).
    case invalidResponse
    case unknown

    /// Trying the same request again later may succeed.
    public var isTransient: Bool {
        switch self {
        case .networkUnavailable, .timeout, .rateLimited, .serverError: true
        default: false
        }
    }
}

/// Codes the Tatum Tech API sends in `status.statusMessage`. They are machine identifiers, never
/// shown to users; the UI maps them to its own copy.
public enum TatumTechServerCode: String, Sendable, CaseIterable {
    case userAlreadyExists = "USER_ALREADY_EXISTS"
    case invalidEmailFormat = "INVALID_EMAIL_FORMAT"
    case invalidPasswordFormat = "INVALID_PASSWORD_FORMAT"
    case passwordsDoNotMatch = "PASSWORDS_DO_NOT_MATCH"
    case wrongEmailOrPassword = "WRONG_EMAIL_OR_PASSWORD"
    case refreshTokenDoesNotExist = "REFRESH_TOKEN_DOES_NOT_EXIST"
    case unauthorized = "UNAUTHORIZED"
    case eventNotFound = "EVENT_NOT_FOUND"

    public init?(code: String?) {
        guard let code = code?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() else { return nil }
        self.init(rawValue: code)
    }

    public var kind: APIErrorKind {
        switch self {
        case .userAlreadyExists: .conflict
        case .invalidEmailFormat, .invalidPasswordFormat, .passwordsDoNotMatch: .badRequest
        case .wrongEmailOrPassword, .refreshTokenDoesNotExist, .unauthorized: .unauthorized
        case .eventNotFound: .notFound
        }
    }
}

public struct ClassifiedAPIError: Sendable, Equatable {
    public let kind: APIErrorKind
    /// Status the API reported (in the body for Tatum Tech envelopes), when known.
    public let statusCode: Int?
    /// Machine code such as `USER_ALREADY_EXISTS`, when the server sent one.
    public let serverCode: String?
    /// Server text that passed `SafeServerMessage`; `nil` otherwise.
    public let userMessage: String?

    public init(kind: APIErrorKind, statusCode: Int? = nil, serverCode: String? = nil, userMessage: String? = nil) {
        self.kind = kind
        self.statusCode = statusCode
        self.serverCode = serverCode
        self.userMessage = userMessage
    }

    public var knownServerCode: TatumTechServerCode? { TatumTechServerCode(code: serverCode) }
}

/// The single place that interprets HTTP statuses, server codes, and transport failures.
/// Screens never inspect status codes themselves.
public enum APIErrorClassifier {

    public static func classify(_ error: any Error) -> ClassifiedAPIError {
        if error is TimeoutError { return ClassifiedAPIError(kind: .timeout) }
        guard let apiError = error as? APIError else { return ClassifiedAPIError(kind: .unknown) }
        switch apiError {
        case let .http(statusCode, messages):
            return classifyHTTP(statusCode: statusCode, messages: messages)
        case .network:
            return ClassifiedAPIError(kind: .networkUnavailable)
        case .timeout:
            return ClassifiedAPIError(kind: .timeout)
        case .decoding:
            return ClassifiedAPIError(kind: .invalidResponse)
        case .unexpected:
            return ClassifiedAPIError(kind: .unknown)
        }
    }

    /// Category for a status code alone, used when the server sent no recognized code.
    public static func kind(forStatus statusCode: Int) -> APIErrorKind {
        switch statusCode {
        case 401: .unauthorized
        case 403: .forbidden
        case 404, 410: .notFound
        case 408: .timeout
        case 409: .conflict
        case 429: .rateLimited
        case 400..<500: .badRequest
        case 500..<600: .serverError
        default: .unknown
        }
    }

    /// `USER_ALREADY_EXISTS`-style identifiers, as opposed to sentences meant for people.
    public static func isMachineCode(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.range(of: "^[A-Z][A-Z0-9]*(_[A-Z0-9]+)+$|^[A-Z]{3,}$", options: .regularExpression) != nil
    }

    private static func classifyHTTP(statusCode: Int, messages: [String]) -> ClassifiedAPIError {
        let texts = messages
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let serverCode = texts.first(where: isMachineCode)
        let userMessage = texts.first { !isMachineCode($0) && SafeServerMessage.isSafe($0) }
        let kind = TatumTechServerCode(code: serverCode)?.kind ?? kind(forStatus: statusCode)
        return ClassifiedAPIError(kind: kind, statusCode: statusCode, serverCode: serverCode, userMessage: userMessage)
    }
}

/// Decides whether server-provided text may be shown to users. Anything that looks technical
/// (markup, URLs, stack traces, database or runtime errors) or is too long is rejected, and the
/// UI shows its own copy instead.
public enum SafeServerMessage {
    public static let maxLength = 200

    private static let technical = [
        "exception", "stack ?trace", "traceback", "\\bsql", "syntax error", "undefined", "null ?pointer",
        "\\bnull\\b", "errno", "fatal", "segmentation", "\\bat [A-Za-z0-9_$]+\\.[A-Za-z0-9_$]+", "line \\d+",
        "localhost", "\\b\\d{1,3}(\\.\\d{1,3}){3}\\b",
    ].joined(separator: "|")

    public static func isSafe(_ text: String) -> Bool {
        let message = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (3...maxLength).contains(message.count), message.contains(" ") else { return false }
        if message.contains(where: { "<>{}[]\\`|\n\r\t".contains($0) }) { return false }
        if message.contains("://") || message.lowercased().contains("www.") { return false }
        return message.range(of: technical, options: [.regularExpression, .caseInsensitive]) == nil
    }
}
