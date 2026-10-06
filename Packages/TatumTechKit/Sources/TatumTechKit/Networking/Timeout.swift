import Foundation

public struct TimeoutError: Error, Equatable, Sendable {
    public init() {}
}

/// Runs `operation`, throwing `TimeoutError` if it has not finished after `duration`.
/// The operation is cancelled when the timeout wins.
public func withTimeout<T: Sendable>(
    _ duration: Duration,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(for: duration)
            throw TimeoutError()
        }
        defer { group.cancelAll() }
        guard let result = try await group.next() else { throw CancellationError() }
        return result
    }
}
