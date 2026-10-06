import Foundation

/// Profile photos for the user's contact card, stored as JPEG files in Application Support.
/// Only the file name is kept in `ContactCard`, so the directory can move between installs.
struct ContactCardImageStore: Sendable {
    let directory: URL?

    /// Photos in `Application Support/ContactCardImages`, or nowhere (UI tests) when `nil`.
    static func live() -> ContactCardImageStore {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        return ContactCardImageStore(directory: base?.appendingPathComponent("ContactCardImages", isDirectory: true))
    }

    static let inMemory = ContactCardImageStore(directory: nil)

    func url(for fileName: String?) -> URL? {
        guard let directory, let fileName, !fileName.isEmpty else { return nil }
        let url = directory.appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Writes `jpegData` under a new name and returns that name.
    func save(jpegData: Data) throws -> String {
        guard let directory else { throw CocoaError(.fileWriteNoPermission) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let name = "photo_\(Int64(Date().timeIntervalSince1970 * 1000)).jpg"
        try jpegData.write(to: directory.appendingPathComponent(name), options: [.atomic, .completeFileProtection])
        return name
    }

    func delete(_ fileName: String?) {
        guard let url = url(for: fileName) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    func deleteAll() {
        guard let directory else { return }
        try? FileManager.default.removeItem(at: directory)
    }
}
