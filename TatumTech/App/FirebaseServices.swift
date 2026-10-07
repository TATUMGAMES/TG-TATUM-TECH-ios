import Foundation
import OSLog
import TatumTechKit
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif
#if canImport(FirebaseCrashlytics)
import FirebaseCrashlytics
#endif

/// What Firebase was started with. Shown in the Debug build's diagnostics panel; never holds the
/// API key or OAuth client IDs.
struct FirebaseDiagnostics: Sendable, Equatable {
    var bundleIdentifier: String
    var check: FirebaseConfigurationCheck
    var configuration: FirebaseConfigurationSummary?
    var isConfigured: Bool

    static let disabled = FirebaseDiagnostics(
        bundleIdentifier: Bundle.main.bundleIdentifier ?? "",
        check: .missingConfiguration,
        configuration: nil,
        isConfigured: false
    )

    var environmentName: String {
        FirebaseEnvironment(bundleIdentifier: bundleIdentifier)?.displayName ?? "Unregistered"
    }
}

/// Starts Firebase from the single `GoogleService-Info.plist` the build bundled for this
/// configuration, after checking that it belongs to the running bundle ID. Builds without one (for
/// example a fresh clone) or with a mismatched one run normally with analytics and crash
/// reporting turned off.
enum FirebaseServices {
    private static let logger = Logger(subsystem: AppLog.subsystem, category: "Firebase")

    /// Configures Firebase once and returns the analytics clients to use.
    @MainActor
    static func configure(bundle: Bundle = .main) -> (clients: [any AnalyticsClient], diagnostics: FirebaseDiagnostics) {
        let path = bundle.path(forResource: "GoogleService-Info", ofType: "plist")
        let plist = path.flatMap { NSDictionary(contentsOfFile: $0) as? [String: Any] }
        let check = FirebaseConfigurationCheck.evaluate(appBundleIdentifier: bundle.bundleIdentifier, plist: plist)
        var diagnostics = FirebaseDiagnostics(
            bundleIdentifier: bundle.bundleIdentifier ?? "",
            check: check,
            configuration: plist.flatMap(FirebaseConfigurationSummary.init(plist:)),
            isConfigured: false
        )
        guard case let .valid(environment) = check else {
            if check == .missingConfiguration {
                logger.notice("\(check.summary, privacy: .public); analytics and crash reporting are off")
            } else {
                logger.fault("\(check.summary, privacy: .public); Firebase was not started")
            }
            return ([], diagnostics)
        }

        #if canImport(FirebaseCore) && canImport(FirebaseAnalytics) && canImport(FirebaseCrashlytics)
        guard let path, let options = FirebaseOptions(contentsOfFile: path) else {
            logger.fault("GoogleService-Info.plist could not be loaded; Firebase was not started")
            return ([], diagnostics)
        }
        if FirebaseApp.app() == nil {
            FirebaseApp.configure(options: options)
        }
        let crashlytics = Crashlytics.crashlytics()
        crashlytics.setCustomValue(environment.bundleIdentifier, forKey: "application_id")
        crashlytics.setCustomValue(environment == .debug ? "debug" : "release", forKey: "build_type")
        diagnostics.isConfigured = true
        logger.info("Firebase started: \(environment.displayName, privacy: .public), app \(options.googleAppID, privacy: .public)")
        return ([FirebaseAnalyticsClient()], diagnostics)
        #else
        return ([], diagnostics)
        #endif
    }
}

/// Adds a best-effort `exception` (handled = false) event for uncaught Objective-C exceptions, then
/// hands the exception to the handler installed before it (Crashlytics). Swift runtime traps
/// cannot be intercepted; Crashlytics reports those on the next launch.
enum UnhandledExceptionBridge {
    nonisolated(unsafe) private static var analytics: AnalyticsService?
    nonisolated(unsafe) private static var previous: (@convention(c) (NSException) -> Void)?

    @MainActor
    static func install(analytics: AnalyticsService) {
        guard self.analytics == nil else { return }
        self.analytics = analytics
        previous = NSGetUncaughtExceptionHandler()
        NSSetUncaughtExceptionHandler { exception in
            UnhandledExceptionBridge.analytics?.recordUnhandled(UncaughtException(name: exception.name.rawValue))
            UnhandledExceptionBridge.previous?(exception)
        }
    }

    private struct UncaughtException: Error {
        let name: String
    }
}

#if canImport(FirebaseAnalytics) && canImport(FirebaseCrashlytics)
/// Sends events to Firebase Analytics and non-fatal errors to Crashlytics.
struct FirebaseAnalyticsClient: AnalyticsClient {
    func log(name: String, parameters: [String: AnalyticsValue]) {
        let values: [String: Any] = parameters.mapValues { value in
            switch value {
            case let .string(text): text
            case let .integer(number): number
            }
        }
        Analytics.logEvent(name, parameters: values.isEmpty ? nil : values)
    }

    func record(error: any Error) {
        Crashlytics.crashlytics().record(error: error)
    }
}
#endif
