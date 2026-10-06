import Foundation
@testable import TatumTechKit

enum BundledContent {
    static func data(_ name: String) throws -> Data {
        try Fixtures.appContent(name)
    }
}

/// Deterministic generator for reproducible shuffles.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// Collects analytics events in memory.
final class RecordingAnalyticsClient: AnalyticsClient, @unchecked Sendable {
    struct Logged: Equatable {
        let name: String
        let parameters: [String: AnalyticsValue]
    }

    private let lock = NSLock()
    private var logged: [Logged] = []
    private var recorded: [String] = []

    var events: [Logged] { lock.withLock { logged } }
    var errors: [String] { lock.withLock { recorded } }

    func log(name: String, parameters: [String: AnalyticsValue]) {
        lock.withLock { logged.append(Logged(name: name, parameters: parameters)) }
    }

    func record(error: any Error) {
        lock.withLock { recorded.append(String(describing: error)) }
    }
}
