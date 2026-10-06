import Foundation

/// How the user signed in.
public enum AuthMethod: String, Codable, Sendable {
    case email
    case google
    case apple
}

/// A signed-in Tatum Tech API session.
public struct TatumTechSession: Codable, Sendable, Equatable {
    public var accessToken: String
    public var refreshToken: String?
    /// Access-token expiry, or `nil` if the server did not say.
    public var expiresAt: Date?
    public var authMethod: AuthMethod
    public var user: TatumTechUser?

    public init(
        accessToken: String,
        refreshToken: String?,
        expiresAt: Date?,
        authMethod: AuthMethod,
        user: TatumTechUser? = nil
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.authMethod = authMethod
        self.user = user
    }
}

extension TatumTechSession: CustomStringConvertible {
    /// Never includes tokens, so sessions are safe to log.
    public var description: String {
        "TatumTechSession(authMethod: \(authMethod), expiresAt: \(expiresAt.map(String.init(describing:)) ?? "nil"), userID: \(user?.id ?? "nil"))"
    }
}

/// Supplies the stable random id sent as `deviceId` with authentication requests.
public protocol DeviceIdentifierProvider: Sendable {
    func deviceID() -> String
}

/// Device id kept in `UserDefaults`, created on first use. It is not a secret, and resetting it on
/// reinstall matches the Android app.
public struct UserDefaultsDeviceIdentifier: DeviceIdentifierProvider, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "tatumTech.deviceID") {
        self.defaults = defaults
        self.key = key
    }

    public func deviceID() -> String {
        if let existing = defaults.string(forKey: key) { return existing }
        let created = UUID().uuidString.lowercased()
        defaults.set(created, forKey: key)
        return created
    }
}

public struct FixedDeviceIdentifier: DeviceIdentifierProvider {
    private let value: String
    public init(_ value: String) { self.value = value }
    public func deviceID() -> String { value }
}
