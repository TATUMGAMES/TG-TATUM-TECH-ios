import Foundation

/// A Tatum Tech API call that failed (HTTP error, no connection, or an undecodable body).
public struct APIRequestFailure: Sendable {
    public let method: HTTPMethod
    public let url: URL
    public let durationMilliseconds: Int
    public let error: APIError
    /// HTTP status of the response, when one arrived. Differs from `error.statusCode` when the API
    /// reported the failure inside an HTTP 200 envelope.
    public let responseStatusCode: Int?
    /// Raw response body, for credential-masked developer logs only.
    public let responseBody: Data?

    public init(
        method: HTTPMethod,
        url: URL,
        durationMilliseconds: Int,
        error: APIError,
        responseStatusCode: Int? = nil,
        responseBody: Data? = nil
    ) {
        self.method = method
        self.url = url
        self.durationMilliseconds = durationMilliseconds
        self.error = error
        self.responseStatusCode = responseStatusCode
        self.responseBody = responseBody
    }
}

/// Told about every failed API call, e.g. to report it to analytics. Cancellations are not failures.
public protocol APIFailureObserver: Sendable {
    func requestFailed(_ failure: APIRequestFailure)
}

/// Forwards every failure to each observer, e.g. analytics and a Debug-only logger.
public struct APIFailureObservers: APIFailureObserver {
    private let observers: [any APIFailureObserver]

    public init(_ observers: [any APIFailureObserver]) {
        self.observers = observers
    }

    public func requestFailed(_ failure: APIRequestFailure) {
        for observer in observers { observer.requestFailed(failure) }
    }
}

extension Duration {
    var wholeMilliseconds: Int {
        let (seconds, attoseconds) = components
        return Int(seconds) * 1000 + Int(attoseconds / 1_000_000_000_000_000)
    }
}
