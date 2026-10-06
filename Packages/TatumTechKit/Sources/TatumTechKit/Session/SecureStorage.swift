import Foundation
#if canImport(Security)
import Security
#endif

/// Stores small secrets by key. The app uses the Keychain; tests use `InMemorySecureStore`.
public protocol SecureStore: Sendable {
    func data(forKey key: String) throws -> Data?
    func set(_ data: Data, forKey key: String) throws
    func removeValue(forKey key: String) throws
}

public struct SecureStoreError: Error, Equatable, Sendable {
    public let status: Int32
    public init(status: Int32) { self.status = status }
}

/// Reads and writes one `Codable` value in a `SecureStore`.
public struct SecureValue<Value: Codable & Sendable>: Sendable {
    private let store: any SecureStore
    private let key: String

    public init(store: any SecureStore, key: String) {
        self.store = store
        self.key = key
    }

    /// The stored value, or `nil` if there is none or it can no longer be decoded.
    public func load() -> Value? {
        guard let data = try? store.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Value.self, from: data)
    }

    public func save(_ value: Value) throws {
        try store.set(try JSONEncoder().encode(value), forKey: key)
    }

    public func clear() {
        try? store.removeValue(forKey: key)
    }
}

/// Thread-safe in-memory store for tests and previews.
public final class InMemorySecureStore: SecureStore, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Data] = [:]
    /// When set, every write throws this error.
    public var failWrites: SecureStoreError?

    public init() {}

    public func data(forKey key: String) throws -> Data? {
        lock.lock(); defer { lock.unlock() }
        return values[key]
    }

    public func set(_ data: Data, forKey key: String) throws {
        lock.lock(); defer { lock.unlock() }
        if let failWrites { throw failWrites }
        values[key] = data
    }

    public func removeValue(forKey key: String) throws {
        lock.lock(); defer { lock.unlock() }
        values[key] = nil
    }
}

#if canImport(Security)
/// Generic-password Keychain items for this app.
///
/// Items are readable after the first unlock and never leave the device (no iCloud Keychain sync,
/// not restored onto another device from a backup).
public struct KeychainStore: SecureStore {
    private let service: String

    public init(service: String) {
        self.service = service
    }

    public func data(forKey key: String) throws -> Data? {
        var query = baseQuery(key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess: return result as? Data
        case errSecItemNotFound: return nil
        default: throw SecureStoreError(status: status)
        }
    }

    public func set(_ data: Data, forKey key: String) throws {
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let updateStatus = SecItemUpdate(baseQuery(key) as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else { throw SecureStoreError(status: updateStatus) }

        let addStatus = SecItemAdd(baseQuery(key).merging(attributes) { $1 } as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw SecureStoreError(status: addStatus) }
    }

    public func removeValue(forKey key: String) throws {
        let status = SecItemDelete(baseQuery(key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SecureStoreError(status: status)
        }
    }

    /// Deletes every item this store owns, e.g. on the first launch after a reinstall
    /// (Keychain items outlive app deletion).
    public func removeAll() {
        SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ] as CFDictionary)
    }

    private func baseQuery(_ key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
    }
}
#endif
