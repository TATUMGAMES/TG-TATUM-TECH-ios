import Foundation

/// The Firebase app a build reports to. The app's bundle identifier decides it, not the build
/// configuration, so a build can never send data to the other environment's Firebase app.
public enum FirebaseEnvironment: String, CaseIterable, Sendable {
    case debug
    case production

    /// The environment registered for `bundleIdentifier`, or nil for any other bundle.
    public init?(bundleIdentifier: String?) {
        guard let match = Self.allCases.first(where: { $0.bundleIdentifier == bundleIdentifier }) else {
            return nil
        }
        self = match
    }

    public var bundleIdentifier: String {
        switch self {
        case .debug: "com.tatumgames.tatumtech.ios.debug"
        case .production: "com.tatumgames.tatumtech.ios"
        }
    }

    /// The Firebase iOS app registered for this bundle ID (project `tatumtech-mobile-firebase`).
    /// App IDs are public identifiers, not credentials.
    public var googleAppID: String {
        switch self {
        case .debug: "1:200853064929:ios:fca90eb9865f2e2bd6fba0"
        case .production: "1:200853064929:ios:56260bb200c2ad8fd6fba0"
        }
    }

    public var displayName: String {
        switch self {
        case .debug: "Tatum Tech Debug"
        case .production: "Tatum Tech Prod"
        }
    }
}

/// The identifying fields of a `GoogleService-Info.plist`. API keys and OAuth client IDs are
/// deliberately not read, so this value is safe to log and show in diagnostics.
public struct FirebaseConfigurationSummary: Sendable, Equatable {
    public var bundleIdentifier: String
    public var googleAppID: String
    public var projectID: String

    public init(bundleIdentifier: String, googleAppID: String, projectID: String) {
        self.bundleIdentifier = bundleIdentifier
        self.googleAppID = googleAppID
        self.projectID = projectID
    }

    /// Reads `BUNDLE_ID`, `GOOGLE_APP_ID` and `PROJECT_ID`; nil when any of them is missing or empty.
    public init?(plist: [String: Any]) {
        func value(_ key: String) -> String? {
            guard let text = (plist[key] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !text.isEmpty else { return nil }
            return text
        }
        guard let bundleIdentifier = value("BUNDLE_ID"),
              let googleAppID = value("GOOGLE_APP_ID"),
              let projectID = value("PROJECT_ID") else { return nil }
        self.init(bundleIdentifier: bundleIdentifier, googleAppID: googleAppID, projectID: projectID)
    }
}

/// Whether the bundled Firebase configuration belongs to the running app. Firebase starts only
/// for `.valid`; every other result leaves analytics and crash reporting off.
public enum FirebaseConfigurationCheck: Sendable, Equatable {
    case valid(FirebaseEnvironment)
    /// No `GoogleService-Info.plist` in the app bundle.
    case missingConfiguration
    /// The plist exists but lacks `BUNDLE_ID`, `GOOGLE_APP_ID` or `PROJECT_ID`.
    case unreadableConfiguration
    /// The app's bundle ID is not one of the registered Firebase apps.
    case unknownBundleIdentifier(String?)
    /// The plist was downloaded for a different bundle ID than the running app.
    case bundleMismatch(app: String, configuration: String)
    /// The plist matches the bundle ID but names a different Firebase app.
    case appIDMismatch(expected: String, configuration: String)

    public static func evaluate(appBundleIdentifier: String?, plist: [String: Any]?) -> Self {
        guard let plist else { return .missingConfiguration }
        guard let configuration = FirebaseConfigurationSummary(plist: plist) else {
            return .unreadableConfiguration
        }
        guard let environment = FirebaseEnvironment(bundleIdentifier: appBundleIdentifier) else {
            return .unknownBundleIdentifier(appBundleIdentifier)
        }
        guard configuration.bundleIdentifier == environment.bundleIdentifier else {
            return .bundleMismatch(app: environment.bundleIdentifier, configuration: configuration.bundleIdentifier)
        }
        guard configuration.googleAppID == environment.googleAppID else {
            return .appIDMismatch(expected: environment.googleAppID, configuration: configuration.googleAppID)
        }
        return .valid(environment)
    }

    /// One-line explanation for logs and the debug diagnostics panel.
    public var summary: String {
        switch self {
        case let .valid(environment):
            "Configured for \(environment.displayName)"
        case .missingConfiguration:
            "GoogleService-Info.plist is not bundled"
        case .unreadableConfiguration:
            "GoogleService-Info.plist is missing BUNDLE_ID, GOOGLE_APP_ID or PROJECT_ID"
        case let .unknownBundleIdentifier(bundleIdentifier):
            "Bundle ID \(bundleIdentifier ?? "(none)") has no registered Firebase app"
        case let .bundleMismatch(app, configuration):
            "GoogleService-Info.plist is for \(configuration), but this app is \(app)"
        case let .appIDMismatch(expected, configuration):
            "GoogleService-Info.plist names Firebase app \(configuration), expected \(expected)"
        }
    }
}
