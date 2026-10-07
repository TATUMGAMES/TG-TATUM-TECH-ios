import Foundation
import TatumTechKit
import UserNotifications

/// Services shared by every screen, built once at launch.
@MainActor
struct AppDependencies {
    let configuration: AppConfiguration
    let accountService: AccountService
    let content: any ContentRepository
    let googleSignIn: any GoogleSignInProviding
    let appleCredentials: any AppleCredentialStateChecking
    /// The user's on-device data: profile, progress, timeline, contact card, notifications.
    let local: LocalRepository
    let catalog: BundledCatalog
    let analytics: AnalyticsService
    let firebase: FirebaseDiagnostics
    let discord: DiscordClient
    let contactImages: ContactCardImageStore
    let reminders: MeetingReminderCenter
    /// Numeric App Store ID for the review link, when the store record exists.
    let appStoreID: String?

    /// Live services, or deterministic offline ones when launched by UI tests.
    static func makeForLaunch(processInfo: ProcessInfo = .processInfo) -> AppDependencies {
        let arguments = processInfo.arguments
        if arguments.contains(LaunchArgument.uiTesting) {
            return uiTesting(signedIn: arguments.contains(LaunchArgument.uiTestingSignedIn))
        }
        return live()
    }

    static func live(bundle: Bundle = .main) -> AppDependencies {
        let configuration = AppConfiguration.resolve(
            infoDictionary: bundle.infoDictionary ?? [:],
            isDebugBuild: BuildFlavor.isDebug
        )
        let keychain = KeychainStore(service: "\(bundle.bundleIdentifier ?? "com.tatumgames.tatumtech").auth")
        FirstLaunchGuard().clearCredentialsAfterReinstall(keychain)
        let firebase = FirebaseServices.configure(bundle: bundle)
        let analytics = AnalyticsService(clients: firebase.clients)
        UnhandledExceptionBridge.install(analytics: analytics)

        let transport: any HTTPTransport = switch configuration.dataSource {
        case .network: URLSessionTransport()
        case .localJSON: LocalJSONTransport(loadFile: BundledContent.loader)
        }
        let client = TatumTechAPIClient(
            baseURL: configuration.environment.baseURL,
            apiKey: configuration.apiKey,
            transport: transport,
            logger: configuration.logsHTTPTraffic ? OSLogTrafficLogger() : nil,
            failureObserver: analytics
        )
        let appStoreID = (bundle.object(forInfoDictionaryKey: "TatumTechAppStoreID") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return AppDependencies(
            configuration: configuration,
            client: client,
            secureStore: keychain,
            googleSignIn: GoogleSignInProviderFactory.make(bundle: bundle),
            appleCredentials: AppleIDCredentialStateChecker(),
            local: LocalRepository(fileURL: LocalDataLocation.fileURL),
            analytics: analytics,
            firebase: firebase.diagnostics,
            discordTransport: URLSessionTransport(),
            contactImages: .live(),
            reminders: MeetingReminderCenter(notifications: .current()),
            appStoreID: appStoreID?.isEmpty == false ? appStoreID : nil
        )
    }

    /// Bundled JSON, in-memory storage, and no external services, so UI tests never touch the
    /// network, the Keychain, or notifications.
    static func uiTesting(signedIn: Bool) -> AppDependencies {
        let configuration = AppConfiguration(environment: .production, dataSource: .localJSON)
        let client = TatumTechAPIClient(
            baseURL: configuration.environment.baseURL,
            transport: LocalJSONTransport(loadFile: BundledContent.loader)
        )
        let store = InMemorySecureStore()
        if signedIn {
            let account = FederatedAccount(provider: .apple, userID: "ui-test-user", displayName: "Ada")
            try? SecureValue<FederatedAccount>(store: store, key: StorageKey.federatedAccount).save(account)
        }
        return AppDependencies(
            configuration: configuration,
            client: client,
            secureStore: store,
            googleSignIn: UnavailableGoogleSignIn(),
            appleCredentials: AuthorizedAppleCredentials(),
            local: LocalRepository(fileURL: nil),
            analytics: .disabled,
            firebase: .disabled,
            discordTransport: OfflineTransport(),
            contactImages: .inMemory,
            reminders: MeetingReminderCenter(notifications: nil, defaults: UserDefaults(suiteName: "ui-testing") ?? .standard),
            appStoreID: nil
        )
    }

    private init(
        configuration: AppConfiguration,
        client: TatumTechAPIClient,
        secureStore: any SecureStore,
        googleSignIn: any GoogleSignInProviding,
        appleCredentials: any AppleCredentialStateChecking,
        local: LocalRepository,
        analytics: AnalyticsService,
        firebase: FirebaseDiagnostics,
        discordTransport: any HTTPTransport,
        contactImages: ContactCardImageStore,
        reminders: MeetingReminderCenter,
        appStoreID: String?
    ) {
        let sessionManager = SessionManager(
            client: client,
            store: SecureValue(store: secureStore, key: StorageKey.session),
            deviceIdentifier: UserDefaultsDeviceIdentifier()
        )
        self.configuration = configuration
        self.accountService = AccountService(
            sessionManager: sessionManager,
            federatedStore: SecureValue(store: secureStore, key: StorageKey.federatedAccount)
        )
        self.content = APIContentRepository(client: client)
        self.googleSignIn = googleSignIn
        self.appleCredentials = appleCredentials
        self.local = local
        self.catalog = BundledCatalog(loadFile: BundledContent.loader)
        self.analytics = analytics
        self.firebase = firebase
        self.discord = DiscordClient(transport: discordTransport, analytics: analytics)
        self.contactImages = contactImages
        self.reminders = reminders
        self.appStoreID = appStoreID
    }
}

enum LaunchArgument {
    static let uiTesting = "-uiTesting"
    static let uiTestingSignedIn = "-uiTestingSignedIn"
}

enum BuildFlavor {
    static var isDebug: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }
}

private enum StorageKey {
    static let session = "tatumTech.session"
    static let federatedAccount = "tatumTech.federatedAccount"
}

/// Where the on-device data document lives. Application Support is backed up and is not purged
/// by the system, unlike Caches.
enum LocalDataLocation {
    static var fileURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("TatumTech", isDirectory: true)
            .appendingPathComponent("local-data.json")
    }
}

/// Reads JSON files bundled in `Resources/Content`.
enum BundledContent {
    static let loader: @Sendable (String) throws -> Data = { name in try load(name) }

    static func load(_ name: String) throws -> Data {
        guard let url = Bundle.main.url(forResource: name, withExtension: nil) else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try Data(contentsOf: url)
    }
}

/// Fails every request as if the device were offline. Used by UI tests for third-party APIs.
struct OfflineTransport: HTTPTransport {
    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        throw URLError(.notConnectedToInternet)
    }
}

/// Keychain items survive app deletion; UserDefaults do not. On the first launch after an install,
/// clear credentials left behind by a previous install so a reinstall starts signed out.
struct FirstLaunchGuard {
    var defaults: UserDefaults = .standard
    private let key = "tatumTech.hasLaunchedBefore"

    func clearCredentialsAfterReinstall(_ keychain: KeychainStore) {
        guard !defaults.bool(forKey: key) else { return }
        keychain.removeAll()
        defaults.set(true, forKey: key)
    }
}
