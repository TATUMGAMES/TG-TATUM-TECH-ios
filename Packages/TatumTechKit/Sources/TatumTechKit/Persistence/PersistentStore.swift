import Foundation

/// A Codable value kept in memory and written atomically to a JSON file after every change.
///
/// Pass `fileURL: nil` for an in-memory store (tests, UI tests). A file that cannot be decoded
/// (for example after a downgrade) is moved aside as `<name>.corrupt` and the store starts empty,
/// so a bad file never blocks launch.
public actor PersistentStore<Value: Codable & Sendable> {
    private var value: Value
    private let fileURL: URL?
    private let makeEmpty: @Sendable () -> Value
    /// The last error writing to disk, if any; the in-memory value stays authoritative.
    public private(set) var lastWriteError: String?

    public init(fileURL: URL?, empty: @escaping @Sendable () -> Value) {
        self.fileURL = fileURL
        self.makeEmpty = empty
        self.value = Self.load(from: fileURL) ?? empty()
    }

    /// Reads the current value.
    public func read<T: Sendable>(_ body: @Sendable (Value) throws -> T) rethrows -> T {
        try body(value)
    }

    /// The current value.
    public var current: Value { value }

    /// Changes the value and saves it. Nothing is saved if `body` throws.
    @discardableResult
    public func update<T: Sendable>(_ body: @Sendable (inout Value) throws -> T) rethrows -> T {
        var copy = value
        let result = try body(&copy)
        value = copy
        save()
        return result
    }

    /// Replaces the value with an empty one, then lets `body` restore anything that must survive.
    public func reset(keeping body: @Sendable (Value, inout Value) -> Void = { _, _ in }) {
        var fresh = makeEmpty()
        body(value, &fresh)
        value = fresh
        save()
    }

    private func save() {
        guard let fileURL else { return }
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .millisecondsSince1970
            let data = try encoder.encode(value)
            try data.write(to: fileURL, options: [.atomic])
            lastWriteError = nil
        } catch {
            lastWriteError = String(describing: error)
        }
    }

    private static func load(from url: URL?) -> Value? {
        guard let url, FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .millisecondsSince1970
            return try decoder.decode(Value.self, from: Data(contentsOf: url))
        } catch {
            let backup = url.appendingPathExtension("corrupt")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.moveItem(at: url, to: backup)
            return nil
        }
    }
}
