import Foundation

/// Typed operations on the on-device data. All writes are saved immediately.
public struct LocalRepository: Sendable {
    public let store: PersistentStore<LocalData>

    public init(store: PersistentStore<LocalData>) {
        self.store = store
    }

    /// A repository persisted to `fileURL`, or in memory when `nil`.
    public init(fileURL: URL?) {
        self.store = PersistentStore(fileURL: fileURL) { LocalData() }
    }

    public func snapshot() async -> LocalData {
        await store.current
    }

    // MARK: User

    public func currentUser() async -> LocalUser? {
        await store.read { $0.user }
    }

    /// The local user, created anonymously on first call. `seedFirstName`/`seedLastName` (for
    /// example from the signed-in account) fill a new user's names.
    @discardableResult
    public func ensureUser(seedFirstName: String? = nil, seedLastName: String? = nil) async -> LocalUser {
        await store.update { data in
            if let user = data.user { return user }
            var generator = SystemRandomNumberGenerator()
            var user = LocalUser.anonymous(using: &generator)
            user.firstName = seedFirstName?.nonBlank
            user.lastName = seedLastName?.nonBlank
            data.user = user
            return user
        }
    }

    /// Saves profile edits (blank values clear a field) and returns the fields that changed.
    @discardableResult
    public func updateProfile(firstName: String, lastName: String, email: String) async -> [ProfileField] {
        await ensureUser()
        return await store.update { data in
            guard var user = data.user else { return [] }
            let newFirst = firstName.isBlankText ? nil : firstName
            let newLast = lastName.isBlankText ? nil : lastName
            let newEmail = email.isBlankText ? nil : email
            var changed: [ProfileField] = []
            if user.firstName != newFirst { changed.append(.firstName) }
            if user.lastName != newLast { changed.append(.lastName) }
            if user.email != newEmail { changed.append(.email) }
            user.firstName = newFirst
            user.lastName = newLast
            user.email = newEmail
            data.user = user
            return changed
        }
    }

    // MARK: Timeline

    @discardableResult
    public func addTimelineEntry(
        _ type: TimelineType,
        description: String,
        relatedID: Int64? = nil,
        at timestamp: Date = Date()
    ) async -> TimelineEntry {
        await store.update { data in data.appendTimeline(type, description: description, relatedID: relatedID, at: timestamp) }
    }

    /// Entries at or after `start`, newest first.
    public func timeline(since start: Date) async -> [TimelineEntry] {
        await store.read { data in
            data.timeline.filter { $0.timestamp >= start }.sorted { $0.timestamp > $1.timestamp }
        }
    }

    public func allTimeline() async -> [TimelineEntry] {
        await store.read { $0.timeline }
    }

    // MARK: Counters

    @discardableResult
    public func incrementCounter(_ key: String) async -> Int {
        await store.update { data in
            let next = (data.counters[key] ?? 0) + 1
            data.counters[key] = next
            return next
        }
    }

    public func counter(_ key: String) async -> Int {
        await store.read { $0.counters[key] ?? 0 }
    }

    public func setCounter(_ key: String, to value: Int) async {
        await store.update { $0.counters[key] = value }
    }

    // MARK: Demographics

    public func demographics() async -> DemographicInfo? {
        await store.read { $0.demographics }
    }

    /// Saves answers; a salary range is only kept alongside an occupation.
    public func saveDemographics(_ info: DemographicInfo) async {
        var cleaned = info
        if cleaned.occupation.isBlankText {
            cleaned.occupation = ""
            cleaned.salaryRange = ""
        }
        let value = cleaned
        await store.update { $0.demographics = value }
    }

    // MARK: Account deletion

    /// Forgets everything stored on this device except whether the user was already sent to the
    /// App Store to rate the app.
    public func deleteAllData() async {
        await store.reset { old, fresh in
            if let sent = old.counters[CounterKey.sentToAppStoreForRating] {
                fresh.counters[CounterKey.sentToAppStoreForRating] = sent
            }
        }
    }
}

extension LocalData {
    @discardableResult
    mutating func appendTimeline(_ type: TimelineType, description: String, relatedID: Int64?, at timestamp: Date) -> TimelineEntry {
        let entry = TimelineEntry(id: nextTimelineID, type: type, description: description, relatedID: relatedID, timestamp: timestamp)
        nextTimelineID += 1
        timeline.append(entry)
        return entry
    }
}

extension String {
    var isBlankText: Bool { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}
