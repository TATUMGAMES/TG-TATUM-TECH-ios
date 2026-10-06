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

/// Starts Firebase when the build contains a `GoogleService-Info.plist`. Builds without one (for
/// example a fresh clone) run normally with analytics and crash reporting turned off.
enum FirebaseServices {
    private static let logger = Logger(subsystem: AppLog.subsystem, category: "Firebase")

    /// Configures Firebase once and returns the analytics clients to use.
    @MainActor
    static func configure(bundle: Bundle = .main) -> [any AnalyticsClient] {
        #if canImport(FirebaseCore) && canImport(FirebaseAnalytics) && canImport(FirebaseCrashlytics)
        guard bundle.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
            logger.notice("GoogleService-Info.plist is not bundled; analytics and crash reporting are off")
            return []
        }
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        return [FirebaseAnalyticsClient()]
        #else
        return []
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
