import Foundation
import TatumTechKit

/// Services shared by every screen, built once at launch.
@MainActor
struct AppDependencies {
    let configuration: AppConfiguration
    let accountService: AccountService
    let content: any ContentRepository
    let googleSignIn: any GoogleSignInProviding
    let appleCredentials: any AppleCredentialStateChecking

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

        let transport: any HTTPTransport = switch configuration.dataSource {
        case .network: URLSessionTransport()
        case .localJSON: LocalJSONTransport(loadFile: BundledContent.loader)
        }
        let client = TatumTechAPIClient(
            baseURL: configuration.environment.baseURL,
            apiKey: configuration.apiKey,
            transport: transport,
            logger: configuration.logsHTTPTraffic ? OSLogTrafficLogger() : nil
        )
        return AppDependencies(
            configuration: configuration,
            client: client,
            secureStore: keychain,
            googleSignIn: GoogleSignInProviderFactory.make(bundle: bundle),
            appleCredentials: AppleIDCredentialStateChecker()
        )
    }

    /// Bundled JSON, in-memory credentials, and no external sign-in, so UI tests never touch the
    /// network or the Keychain.
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
            appleCredentials: AuthorizedAppleCredentials()
        )
    }

    private init(
        configuration: AppConfiguration,
        client: TatumTechAPIClient,
        secureStore: any SecureStore,
        googleSignIn: any GoogleSignInProviding,
        appleCredentials: any AppleCredentialStateChecking
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
