import Foundation

/// What the user was doing when an API call failed. Request-specific failures (validation,
/// conflicts, rejected credentials) are titled after it; service and connectivity failures use a
/// generic title.
public enum APIOperation: Sendable, Equatable {
    case signIn
    case signUp
    case forgotPassword
    case loadContent
    case signOut
}

/// User-facing description of a failed API call, without localized text: the app maps `message`
/// to its copy. Never contains technical details; `serverMessage` is only set for server text that
/// passed `SafeServerMessage`.
public struct APIErrorPresentation: Sendable, Equatable {
    public enum Message: Sendable, Equatable {
        case network
        case timeout
        case badRequest
        case credentialsRejected
        case sessionExpired
        case forbidden
        case notFound
        case conflict
        case rateLimited
        case server
        /// The service is unavailable or answered with something unreadable.
        case service
        case accountExists
        case invalidEmail
        case invalidPassword
        case passwordsDoNotMatch
        case wrongEmailOrPassword
    }

    /// Title after the operation ("Unable to Create Your Account") rather than the generic one.
    public let usesOperationTitle: Bool
    public let message: Message
    /// Shown instead of `message` when present.
    public let serverMessage: String?
    /// Repeating the same request may succeed, so a "Try Again" action makes sense.
    public let canRetry: Bool

    public init(usesOperationTitle: Bool, message: Message, serverMessage: String?, canRetry: Bool) {
        self.usesOperationTitle = usesOperationTitle
        self.message = message
        self.serverMessage = serverMessage
        self.canRetry = canRetry
    }

    /// The single mapping from API failures to alert and error-state copy.
    public init(error: any Error, operation: APIOperation) {
        self.init(classified: APIErrorClassifier.classify(error), operation: operation)
    }

    public init(classified error: ClassifiedAPIError, operation: APIOperation) {
        let known = error.knownServerCode.map(Self.message(for:))
        let requestSpecific = known != nil
            || [.badRequest, .unauthorized, .forbidden, .conflict].contains(error.kind)
            || (error.kind == .notFound && error.serverCode != nil)
        self.init(
            usesOperationTitle: requestSpecific,
            message: known ?? Self.message(for: error, operation: operation),
            serverMessage: known == nil ? error.userMessage : nil,
            canRetry: error.kind.isTransient
        )
    }

    private static func message(for code: TatumTechServerCode) -> Message {
        switch code {
        case .userAlreadyExists: .accountExists
        case .invalidEmailFormat: .invalidEmail
        case .invalidPasswordFormat: .invalidPassword
        case .passwordsDoNotMatch: .passwordsDoNotMatch
        case .wrongEmailOrPassword: .wrongEmailOrPassword
        case .refreshTokenDoesNotExist, .unauthorized: .sessionExpired
        case .eventNotFound: .notFound
        }
    }

    private static func message(for error: ClassifiedAPIError, operation: APIOperation) -> Message {
        switch error.kind {
        case .networkUnavailable: .network
        case .timeout: .timeout
        case .badRequest: .badRequest
        case .unauthorized: operation == .signIn || operation == .signUp ? .credentialsRejected : .sessionExpired
        case .forbidden: .forbidden
        // Without a server code, a 404 means the endpoint itself is missing: a service problem.
        case .notFound: error.serverCode != nil ? .notFound : .service
        case .conflict: .conflict
        case .rateLimited: .rateLimited
        case .serverError: .server
        case .invalidResponse, .unknown: .service
        }
    }
}
