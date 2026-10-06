import Foundation

/// A Tatum Tech API call that failed (HTTP error, no connection, or an undecodable body).
public struct APIRequestFailure: Sendable {
    public let method: HTTPMethod
    public let url: URL
    public let durationMilliseconds: Int
    public let error: APIError

    public init(method: HTTPMethod, url: URL, durationMilliseconds: Int, error: APIError) {
        self.method = method
        self.url = url
        self.durationMilliseconds = durationMilliseconds
        self.error = error
    }
}

/// Told about every failed API call, e.g. to report it to analytics. Cancellations are not failures.
public protocol APIFailureObserver: Sendable {
    func requestFailed(_ failure: APIRequestFailure)
}

extension Duration {
    var wholeMilliseconds: Int {
        let (seconds, attoseconds) = components
        return Int(seconds) * 1000 + Int(attoseconds / 1_000_000_000_000_000)
    }
}
