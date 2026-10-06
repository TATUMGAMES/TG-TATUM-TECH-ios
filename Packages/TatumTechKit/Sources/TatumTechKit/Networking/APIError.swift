import Foundation

/// Why an API call failed. Every client method throws either this or `CancellationError`.
///
/// Associated values are technical detail for logs and tests; never show them to users.
/// Map errors to user-facing copy in the UI layer.
public enum APIError: Error, Sendable, Equatable {
    /// The server answered with a non-2xx status. `messages` are the error messages found in the body.
    case http(statusCode: Int, messages: [String])
    /// The request never got an HTTP answer (offline, DNS, TLS, timeout).
    case network(String)
    /// A 2xx response could not be decoded into the expected model.
    case decoding(String)
    /// Anything else, e.g. a request that could not be built or a session that could not be stored.
    case unexpected(String)

    public var statusCode: Int? {
        if case let .http(statusCode, _) = self { statusCode } else { nil }
    }

    /// First non-blank server message, trimmed.
    public var serverMessage: String? {
        guard case let .http(_, messages) = self else { return nil }
        return messages
            .lazy
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }

    public var isNetworkFailure: Bool {
        if case .network = self { true } else { false }
    }
}

public enum HTTPStatus {
    public static let badRequest = 400
    public static let unauthorized = 401
    public static let forbidden = 403
    public static let notFound = 404
    public static let notImplemented = 501
}
