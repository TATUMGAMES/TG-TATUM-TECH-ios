import Foundation
import Testing
@testable import TatumTechKit

@Suite("Firebase environment selection")
struct FirebaseEnvironmentTests {
    private let debugBundle = "com.tatumgames.tatumtech.ios.debug"
    private let productionBundle = "com.tatumgames.tatumtech.ios"
    private let debugAppID = "1:200853064929:ios:fca90eb9865f2e2bd6fba0"
    private let productionAppID = "1:200853064929:ios:56260bb200c2ad8fd6fba0"

    private func plist(bundle: String, appID: String, project: String = "tatumtech-mobile-firebase") -> [String: Any] {
        ["BUNDLE_ID": bundle, "GOOGLE_APP_ID": appID, "PROJECT_ID": project, "API_KEY": "not-read"]
    }

    @Test func bundleIdentifierSelectsEnvironment() {
        #expect(FirebaseEnvironment(bundleIdentifier: debugBundle) == .debug)
        #expect(FirebaseEnvironment(bundleIdentifier: productionBundle) == .production)
        #expect(FirebaseEnvironment(bundleIdentifier: "com.tatumgames.tatumtech.ios.debug.extra") == nil)
        #expect(FirebaseEnvironment(bundleIdentifier: nil) == nil)
    }

    @Test func environmentNames() {
        #expect(FirebaseEnvironment.debug.displayName == "Tatum Tech Debug")
        #expect(FirebaseEnvironment.production.displayName == "Tatum Tech Prod")
    }

    @Test func matchingConfigurationsAreValid() {
        #expect(FirebaseConfigurationCheck.evaluate(
            appBundleIdentifier: debugBundle,
            plist: plist(bundle: debugBundle, appID: debugAppID)
        ) == .valid(.debug))
        #expect(FirebaseConfigurationCheck.evaluate(
            appBundleIdentifier: productionBundle,
            plist: plist(bundle: productionBundle, appID: productionAppID)
        ) == .valid(.production))
    }

    @Test func swappedConfigurationsAreRejected() {
        #expect(FirebaseConfigurationCheck.evaluate(
            appBundleIdentifier: debugBundle,
            plist: plist(bundle: productionBundle, appID: productionAppID)
        ) == .bundleMismatch(app: debugBundle, configuration: productionBundle))
        #expect(FirebaseConfigurationCheck.evaluate(
            appBundleIdentifier: productionBundle,
            plist: plist(bundle: debugBundle, appID: debugAppID)
        ) == .bundleMismatch(app: productionBundle, configuration: debugBundle))
    }

    @Test func wrongFirebaseAppIsRejected() {
        #expect(FirebaseConfigurationCheck.evaluate(
            appBundleIdentifier: productionBundle,
            plist: plist(bundle: productionBundle, appID: debugAppID)
        ) == .appIDMismatch(expected: productionAppID, configuration: debugAppID))
    }

    @Test func missingUnreadableAndUnknownAreRejected() {
        #expect(FirebaseConfigurationCheck.evaluate(appBundleIdentifier: debugBundle, plist: nil) == .missingConfiguration)
        #expect(FirebaseConfigurationCheck.evaluate(
            appBundleIdentifier: debugBundle,
            plist: ["BUNDLE_ID": debugBundle, "GOOGLE_APP_ID": " "]
        ) == .unreadableConfiguration)
        #expect(FirebaseConfigurationCheck.evaluate(
            appBundleIdentifier: "com.example.other",
            plist: plist(bundle: debugBundle, appID: debugAppID)
        ) == .unknownBundleIdentifier("com.example.other"))
    }

    @Test func summaryNeverIncludesTheAPIKey() {
        let summary = FirebaseConfigurationSummary(plist: plist(bundle: debugBundle, appID: debugAppID))
        #expect(summary == FirebaseConfigurationSummary(
            bundleIdentifier: debugBundle,
            googleAppID: debugAppID,
            projectID: "tatumtech-mobile-firebase"
        ))
        #expect(!String(describing: summary).contains("not-read"))
    }
}
