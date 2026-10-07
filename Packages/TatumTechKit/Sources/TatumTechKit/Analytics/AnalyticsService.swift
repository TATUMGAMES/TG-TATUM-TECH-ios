import Foundation

/// A destination for analytics events and recorded errors (Firebase in the app, a recorder in tests).
public protocol AnalyticsClient: Sendable {
    func log(name: String, parameters: [String: AnalyticsValue])
    /// Records a non-fatal error for crash reporting.
    func record(error: any Error)
}

/// Sends `AnalyticsEvent`s to every configured client. With no clients, events are dropped.
public struct AnalyticsService: Sendable {
    private let clients: [any AnalyticsClient]

    public init(clients: [any AnalyticsClient] = []) {
        self.clients = clients
    }

    /// An analytics service that sends nothing.
    public static let disabled = AnalyticsService()

    public func log(_ event: AnalyticsEvent) {
        for client in clients {
            client.log(name: event.name, parameters: event.parameters)
        }
    }

    /// Records a screen view for `route`, e.g. `game_details_screen/{gameId}`.
    public func navigate(route: String) {
        log(.navigate(screenName: AnalyticsSanitizer.screenName(fromRoute: route)))
    }

    /// Records an error the app recovered from.
    public func recordHandled(_ error: any Error) {
        log(.exception(handled: true))
        for client in clients { client.record(error: error) }
    }

    /// Records an error the app could not recover from.
    public func recordUnhandled(_ error: any Error) {
        log(.exception(handled: false))
        for client in clients { client.record(error: error) }
    }

    /// Records a failed API call and, when provided, the underlying error.
    public func apiError(_ report: APIErrorReport, error: (any Error)? = nil) {
        log(.apiError(report))
        if let error {
            for client in clients { client.record(error: error) }
        }
    }
}

extension AnalyticsService: APIFailureObserver {
    public func requestFailed(_ failure: APIRequestFailure) {
        apiError(
            APIErrorReport(
                endpoint: failure.url.absoluteString,
                method: failure.method.rawValue,
                statusCode: failure.error.statusCode,
                durationMilliseconds: failure.durationMilliseconds,
                errorType: failure.error.analyticsType
            )
        )
    }
}

extension APIError {
    /// Analytics category for a Tatum Tech API failure.
    public var analyticsType: APIErrorType {
        switch self {
        case .http: .http
        case .network, .timeout: .io
        case .decoding: .parse
        case .unexpected: .unknown
        }
    }
}
