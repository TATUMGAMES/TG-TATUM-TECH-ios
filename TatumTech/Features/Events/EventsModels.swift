import Foundation
import Observation
import OSLog
import TatumTechKit

@MainActor
@Observable
final class UpcomingEventsModel {
    private(set) var state: LoadState<[Event]> = .loading
    private let repository: any ContentRepository
    private let logger = Logger(subsystem: AppLog.subsystem, category: "Events")

    init(repository: any ContentRepository) {
        self.repository = repository
    }

    func load() async {
        if case .loaded = state { return }
        await reload()
    }

    func reload() async {
        state = .loading
        do {
            state = .loaded(try await repository.upcomingEvents())
        } catch is CancellationError {
            return
        } catch {
            logger.error("Loading upcoming events failed: \(String(describing: error), privacy: .public)")
            state = .failed
        }
    }
}

@MainActor
@Observable
final class VirtualSpeakersModel {
    private(set) var state: LoadState<[Speaker]> = .loading
    let eventID: String
    private let repository: any ContentRepository
    private let logger = Logger(subsystem: AppLog.subsystem, category: "Events")

    init(eventID: String, repository: any ContentRepository) {
        self.eventID = eventID
        self.repository = repository
    }

    func load() async {
        if case .loaded = state { return }
        await reload()
    }

    func reload() async {
        state = .loading
        do {
            state = .loaded(try await repository.speakers(forEventID: eventID))
        } catch is CancellationError {
            return
        } catch {
            logger.error("Loading speakers failed: \(String(describing: error), privacy: .public)")
            state = .failed
        }
    }
}
