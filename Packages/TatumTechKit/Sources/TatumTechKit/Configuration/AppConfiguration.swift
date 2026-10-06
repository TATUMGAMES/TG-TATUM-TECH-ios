import Foundation

/// Tatum Tech backend deployments.
public enum APIEnvironment: String, CaseIterable, Sendable {
    case production
    case stage

    public var baseURL: URL {
        switch self {
        case .production: URL(string: "https://tg-api-new.uc.r.appspot.com")!
        case .stage: URL(string: "https://tg-api-new-stage.uc.r.appspot.com")!
        }
    }

    /// Parses a build-setting value (case-insensitive), falling back to `.production`.
    public init(settingValue: String?) {
        let normalized = settingValue?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self = Self.allCases.first { $0.rawValue == normalized } ?? .production
    }
}

/// Where API data comes from. Independent of the build configuration: a Debug build can use either.
public enum DataSourceMode: String, CaseIterable, Sendable {
    /// Live Tatum Tech API over HTTPS.
    case network
    /// Known-good JSON bundled with the app, for comparing against the live API.
    case localJSON

    /// Accepts `NETWORK`, `LOCAL_JSON`, `localJSON` (case-insensitive), falling back to `.network`.
    public init(settingValue: String?) {
        let normalized = settingValue?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: "")
            .lowercased()
        self = normalized == "localjson" ? .localJSON : .network
    }
}

/// App-wide settings resolved once at launch from the app's Info.plist, which receives them from
/// the build's `.xcconfig` files.
public struct AppConfiguration: Sendable, Equatable {
    public var environment: APIEnvironment
    public var dataSource: DataSourceMode
    /// Sent as `x-api-key` when present. It ships inside the app, so treat it as a public client key.
    public var apiKey: String?
    /// Enables HTTP traffic logging. Never true in Release builds.
    public var logsHTTPTraffic: Bool

    public init(
        environment: APIEnvironment = .production,
        dataSource: DataSourceMode = .network,
        apiKey: String? = nil,
        logsHTTPTraffic: Bool = false
    ) {
        self.environment = environment
        self.dataSource = dataSource
        self.apiKey = apiKey
        self.logsHTTPTraffic = logsHTTPTraffic
    }

    public enum InfoKey {
        public static let environment = "TatumTechEnvironment"
        public static let dataSource = "TatumTechDataSource"
        public static let apiKey = "TatumTechAPIKey"
    }

    /// Reads the configuration from an Info.plist dictionary.
    ///
    /// Release builds always use the production API over the network, whatever the build settings say.
    public static func resolve(infoDictionary: [String: Any], isDebugBuild: Bool) -> AppConfiguration {
        let apiKey = (infoDictionary[InfoKey.apiKey] as? String)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .flatMap { $0.isEmpty || $0.hasPrefix("$(") ? nil : $0 }
        guard isDebugBuild else {
            return AppConfiguration(environment: .production, dataSource: .network, apiKey: apiKey)
        }
        return AppConfiguration(
            environment: APIEnvironment(settingValue: infoDictionary[InfoKey.environment] as? String),
            dataSource: DataSourceMode(settingValue: infoDictionary[InfoKey.dataSource] as? String),
            apiKey: apiKey,
            logsHTTPTraffic: true
        )
    }
}
